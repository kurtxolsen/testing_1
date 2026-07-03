"""adjprep — one-page adjuster meeting battle card.

Usage:
    adjprep <lead-id>            pull the lead from stormtrack's database
    adjprep --manual             standalone: prompt for the claim facts
    adjprep learn <carrier> "..."   append field intel to carriers.yaml

Carrier intelligence lives in ~/.adjprep/carriers.yaml (override the
directory with ADJPREP_HOME). It is user-maintained: hand-edit it or grow
it with `adjprep learn` after every meeting.
"""

import os
import re
import shutil
import sqlite3
import sys
from datetime import date
from pathlib import Path

import click
import yaml
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import letter
from reportlab.lib.utils import simpleSplit
from reportlab.pdfgen import canvas as pdfcanvas
from rich.console import Console

console = Console()

NAVY = HexColor("#1B3A5C")
GOLD = HexColor("#E8A020")

PAGE_W, PAGE_H = letter

SEED = Path(__file__).parent / "carriers_seed.yaml"


def config_dir() -> Path:
    d = Path(os.environ.get("ADJPREP_HOME", "~/.adjprep")).expanduser()
    d.mkdir(parents=True, exist_ok=True)
    return d


def carriers_path() -> Path:
    path = config_dir() / "carriers.yaml"
    if not path.exists():
        shutil.copy(SEED, path)
        console.print(f"[dim]Seeded carrier intel file at {path}[/dim]")
    return path


def load_carriers() -> dict:
    """Forgiving load: a broken YAML file warns instead of crashing."""
    try:
        data = yaml.safe_load(carriers_path().read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        console.print(f"[yellow]Warning: carriers.yaml has a syntax problem "
                      f"({exc}). Continuing without carrier intel.[/yellow]")
        return {}
    if not isinstance(data, dict):
        console.print("[yellow]Warning: carriers.yaml isn't a mapping — "
                      "continuing without carrier intel.[/yellow]")
        return {}
    return data


def carrier_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def stormtrack_db() -> Path:
    return Path(os.environ.get("STORMTRACK_DB", "~/.stormtrack/stormtrack.db")).expanduser()


def fetch_lead(lead_id: int) -> dict:
    path = stormtrack_db()
    if not path.exists():
        raise click.ClickException(
            f"No stormtrack database at {path}. Use --manual, or run stormtrack first."
        )
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    row = conn.execute("SELECT * FROM leads WHERE id = ?", (lead_id,)).fetchone()
    conn.close()
    if row is None:
        raise click.ClickException(f"No lead #{lead_id} in stormtrack.")
    return dict(row)


# ---------------------------------------------------------------------------
# scope + checklist derivation

DAMAGE_CHECKLIST = [
    "10x10 test squares chalked on EVERY slope",
    "Soft metals: gutters, downspouts, AC fins, window wraps",
    "Wind damage: creased / lifted / missing shingles",
    "Interior: ceiling stains, attic decking moisture",
    "Code items: drip edge, ice & water barrier",
    "Elevation photos: all four sides + address shot",
]

# Plain-English approximations of common Xactimate-style line items —
# NOT licensed Xactimate codes, just meeting shorthand.
SCOPE_RULES = [
    (r"hail|bruis|impact|granul", "Laminated comp shingle — remove & replace (RFG 240-class)"),
    (r"wind|creas|lift|missing", "Wind-damaged shingle replacement / ridge cap"),
    (r"gutter|downspout|soft metal", "R&R gutters & downspouts — aluminum, 5in"),
    (r"ac |a/c|condenser|fin", "Comb AC condenser fins"),
    (r"leak|interior|ceiling|stain", "Interior repair: seal, texture & paint affected ceiling"),
    (r"fence|paint", "Refinish fence / exterior paint collateral"),
    (r"window|screen|wrap", "Window screens / metal wraps replacement"),
]

BASE_SCOPE = [
    "Tear-off & haul-off (all layers — verify layer count)",
    "Felt/synthetic underlayment",
    "Drip edge — eaves & rakes (code)",
    "Ice & water barrier at valleys/penetrations (code)",
    "Pipe jacks, vents & flashing accessories",
    "Steep / high charges if applicable",
]


def derive_scope(damage_text: str) -> list[str]:
    items = list(BASE_SCOPE)
    text = (damage_text or "").lower()
    for pattern, item in SCOPE_RULES:
        if re.search(pattern, text) and item not in items:
            items.append(item)
    if not text:
        items.append("Laminated comp shingle — remove & replace (RFG 240-class)")
    return items


# ---------------------------------------------------------------------------
# PDF rendering

def wrap(text, font, size, width):
    return simpleSplit(text, font, size, width)


class Sheet:
    """Cursor-based text layout on a single letter page."""

    def __init__(self, c: pdfcanvas.Canvas):
        self.c = c

    def block(self, x, y, width, lines, size=8.5, leading=11, font="Helvetica",
              color=NAVY, bullet=None):
        self.c.setFillColor(color)
        for raw in lines:
            prefix = bullet or ""
            for i, line in enumerate(wrap(raw, font, size, width - (12 if bullet else 0))):
                self.c.setFont(font, size)
                if bullet and i == 0:
                    self.c.drawString(x, y, prefix)
                    self.c.drawString(x + 12, y, line)
                elif bullet:
                    self.c.drawString(x + 12, y, line)
                else:
                    self.c.drawString(x, y, line)
                y -= leading
        return y

    def heading(self, x, y, text):
        self.c.setFillColor(GOLD)
        self.c.setFont("Helvetica-Bold", 9.5)
        self.c.drawString(x, y, text.upper())
        self.c.setStrokeColor(GOLD)
        self.c.setLineWidth(0.75)
        self.c.line(x, y - 3, x + 30, y - 3)
        return y - 16


def build_pdf(out: Path, lead: dict, intel: dict | None, intel_missing_key: str | None):
    c = pdfcanvas.Canvas(str(out), pagesize=letter)
    s = Sheet(c)
    margin = 36

    # --- header bar
    c.setFillColor(NAVY)
    c.rect(0, PAGE_H - 64, PAGE_W, 64, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 15)
    c.drawString(margin, PAGE_H - 32, f"ADJUSTER PREP — {lead.get('name') or 'Unknown client'}")
    c.setFont("Helvetica", 9.5)
    meeting = lead.get("meeting") or "Meeting: ____________________"
    c.drawString(margin, PAGE_H - 48, (lead.get("address") or "Address: ____________________"))
    c.setFillColor(GOLD)
    c.setFont("Helvetica-Bold", 9.5)
    c.drawRightString(PAGE_W - margin, PAGE_H - 32, meeting)
    c.drawRightString(PAGE_W - margin, PAGE_H - 48,
                      f"Claim #: {lead.get('claim_number') or '____________'}")

    # --- three columns
    col_w = (PAGE_W - 2 * margin - 2 * 18) / 3
    col_x = [margin + i * (col_w + 18) for i in range(3)]
    top = PAGE_H - 92

    y = s.heading(col_x[0], top, "Claim facts")
    facts = [
        f"Carrier: {lead.get('carrier') or '____________'}",
        f"Adjuster: {lead.get('adjuster') or '____________'}",
        f"Adjuster ph: {lead.get('adjuster_phone') or '____________'}",
        f"Storm date: {lead.get('storm_date') or '________'}",
        "NOAA event ref: ____________",
        f"Deductible: {fmt_money(lead.get('deductible'))}",
        f"Policy type: {lead.get('policy_type') or 'RCV / ACV (verify!)'}",
        f"Homeowner ph: {lead.get('phone') or '____________'}",
        f"Est. value: {fmt_money(lead.get('estimated_value'))}",
    ]
    s.block(col_x[0], y, col_w, facts, leading=13)

    y = s.heading(col_x[1], top, "Documented damage")
    s.block(col_x[1], y, col_w, DAMAGE_CHECKLIST, bullet="[  ]", leading=13)
    y2 = y - len(DAMAGE_CHECKLIST) * 13 - 30
    notes = (lead.get("notes") or "").strip()
    if notes:
        y2 = s.heading(col_x[1], y2, "Lead notes")
        s.block(col_x[1], y2, col_w, [notes], size=8, leading=10)

    y = s.heading(col_x[2], top, "Likely scope items")
    scope = derive_scope(f"{lead.get('notes', '')} {lead.get('damage', '')}")
    s.block(col_x[2], y, col_w, scope, bullet="—", leading=12)

    # --- carrier intel band
    band_top = 236
    c.setFillColor(HexColor("#F0F2F5"))
    c.rect(0, 64, PAGE_W, band_top - 64, fill=1, stroke=0)
    carrier_name = (intel or {}).get("display_name") or lead.get("carrier") or "Unknown carrier"
    y = s.heading(margin, band_top - 16, f"Carrier intel — {carrier_name}")
    half = (PAGE_W - 2 * margin - 24) / 2
    if intel:
        c.setFont("Helvetica-Bold", 8.5)
        c.setFillColor(NAVY)
        c.drawString(margin, y, "Their likely pushback")
        c.drawString(margin + half + 24, y, "My counters")
        y -= 12
        s.block(margin, y, half, intel.get("known_pushback") or ["(none recorded)"],
                bullet="•", size=8, leading=10)
        s.block(margin + half + 24, y, half, intel.get("counter_strategy") or ["(none recorded)"],
                bullet="•", size=8, leading=10)
    else:
        hint = intel_missing_key or "the_carrier"
        s.block(margin, y, PAGE_W - 2 * margin,
                [f'No intel on file — add after meeting:  adjprep learn {hint} "what you observed"'],
                size=9, leading=12)

    # --- footer
    c.setFillColor(NAVY)
    c.rect(0, 0, PAGE_W, 40, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica", 8.5)
    lead_id = lead.get("id", "<id>")
    c.drawString(margin, 16,
                 f"Post-meeting: log outcome ->  stormtrack touch {lead_id} adjuster-meeting "
                 f'"result / next step"')
    c.setFillColor(GOLD)
    c.drawRightString(PAGE_W - margin, 16, f"American Quality Exteriors — {date.today():%b %d, %Y}")

    c.showPage()
    c.save()


def fmt_money(v) -> str:
    try:
        return f"${float(v):,.0f}" if v else "________"
    except (TypeError, ValueError):
        return str(v)


# ---------------------------------------------------------------------------
# output location

def output_path(lead: dict) -> Path:
    clients_dir = Path(os.environ.get("AQE_CLIENTS_DIR", "~/Documents/AQE Clients")).expanduser()
    name = (lead.get("name") or "").strip()
    street = (lead.get("address") or "").split(",")[0].strip()
    last = name.split()[-1] if name else ""
    fname = f"Adjuster Prep — {name or 'client'} — {date.today():%Y-%m-%d}.pdf"

    if clients_dir.is_dir() and last:
        for folder in clients_dir.iterdir():
            if not folder.is_dir():
                continue
            if last.lower() in folder.name.lower() and (
                not street or street.lower() in folder.name.lower()
            ):
                docs = folder / "02 Insurance Docs"
                return (docs if docs.is_dir() else folder) / fname

    desktop = Path.home() / "Desktop"
    return (desktop if desktop.is_dir() else Path.home()) / fname


# ---------------------------------------------------------------------------
# CLI

@click.group(invoke_without_command=False)
@click.version_option()
def cli():
    """adjprep — one-page adjuster meeting battle card."""


@cli.command()
@click.argument("lead_id", type=int, required=False)
@click.option("--manual", is_flag=True, help="Standalone mode: prompt for claim facts")
@click.option("--adjuster", default="", help="Adjuster name")
@click.option("--adjuster-phone", default="", help="Adjuster phone")
@click.option("--policy-type", type=click.Choice(["RCV", "ACV"], case_sensitive=False), default=None)
@click.option("--meeting", default="", help='Meeting date/time, e.g. "Jun 12 2:30 PM"')
@click.option("--out", type=click.Path(), default=None, help="Override output path")
def prep(lead_id, manual, adjuster, adjuster_phone, policy_type, meeting, out):
    """Generate the prep sheet for LEAD_ID (or --manual).

    Example: adjprep 7 --adjuster "D. Reeves" --policy-type RCV --meeting "Fri 2:30 PM"
    """
    if manual:
        lead = {
            "id": "<id>",
            "name": click.prompt("Client name"),
            "address": click.prompt("Address", default=""),
            "phone": click.prompt("Homeowner phone", default=""),
            "carrier": click.prompt("Carrier", default=""),
            "claim_number": click.prompt("Claim #", default=""),
            "storm_date": click.prompt("Storm date", default=""),
            "deductible": click.prompt("Deductible", default=""),
            "notes": click.prompt("Damage notes", default=""),
        }
    elif lead_id is not None:
        lead = fetch_lead(lead_id)
    else:
        raise click.ClickException("Give a stormtrack lead id, or use --manual.")

    if sys.stdin.isatty():
        if not adjuster:
            adjuster = click.prompt("Adjuster name", default="", show_default=False)
        if not adjuster_phone:
            adjuster_phone = click.prompt("Adjuster phone", default="", show_default=False)
        if not policy_type:
            policy_type = click.prompt("Policy type (RCV/ACV)", default="", show_default=False)
        if not meeting:
            meeting = click.prompt("Meeting date/time", default="", show_default=False)

    lead.update({
        "adjuster": adjuster,
        "adjuster_phone": adjuster_phone,
        "policy_type": (policy_type or "").upper() or None,
        "meeting": meeting,
    })

    carriers = load_carriers()
    key = carrier_key(lead.get("carrier") or "")
    intel = carriers.get(key) if key else None

    path = Path(out).expanduser() if out else output_path(lead)
    path.parent.mkdir(parents=True, exist_ok=True)
    build_pdf(path, lead, intel, key or None)
    console.print(f"[green]Prep sheet ready[/green] → {path}")
    if not intel:
        console.print(f'[dim]No carrier intel yet — grow it: adjprep learn {key or "<carrier>"} "..."[/dim]')


@cli.command()
@click.argument("carrier")
@click.argument("observation")
@click.option("--counter", is_flag=True, help="File it under counter_strategy instead of known_pushback")
def learn(carrier, observation, counter):
    """Append field intel for CARRIER so the file compounds with every meeting.

    Example: adjprep learn state_farm "New pushback pattern observed at the Hutchins meeting"
    """
    path = carriers_path()
    data = load_carriers()
    key = carrier_key(carrier)
    entry = data.setdefault(key, {"display_name": carrier.replace("_", " ").title(),
                                  "known_pushback": [], "counter_strategy": []})
    bucket = "counter_strategy" if counter else "known_pushback"
    entry.setdefault(bucket, []).append(observation)
    path.write_text(
        "# carriers.yaml — YOUR field intelligence file. Hand-edit freely.\n"
        + yaml.safe_dump(data, sort_keys=True, allow_unicode=True, width=100),
        encoding="utf-8",
    )
    console.print(f"[green]Learned.[/green] {key}.{bucket} now has "
                  f"{len(entry[bucket])} item(s).")


def main():
    # UX shim: `adjprep 7` means `adjprep prep 7`. Insert the subcommand when
    # the first argument isn't one already.
    known = {"prep", "learn", "--help", "-h", "--version"}
    if len(sys.argv) > 1 and sys.argv[1] not in known:
        sys.argv.insert(1, "prep")
    cli()


if __name__ == "__main__":
    main()
