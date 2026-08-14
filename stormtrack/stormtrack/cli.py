"""stormtrack CLI — lead & claim pipeline for storm-damage restoration sales."""

import csv
import difflib
from datetime import date, datetime, timedelta
from pathlib import Path

import click

# Lazily import rich components to speed up CLI startup time.
_console = None

def get_console():
    global _console
    if _console is None:
        from rich.console import Console as _Console
        _console = _Console()
    return _console

class _ConsoleProxy:
    def __getattr__(self, name):
        return getattr(get_console(), name)

console = _ConsoleProxy()

class _TableFactory:
    def __call__(self, *args, **kwargs):
        from rich.table import Table as _TableClass
        return _TableClass(*args, **kwargs)

Table = _TableFactory()

class _PanelFactory:
    def __call__(self, *args, **kwargs):
        from rich.panel import Panel as _PanelClass
        return _PanelClass(*args, **kwargs)

Panel = _PanelFactory()

from . import db

# Console is lazily constructed via get_console()/console proxy above


# ---------------------------------------------------------------------------
# helpers

def now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def parse_date(value: str) -> str:
    """Accept YYYY-MM-DD, MM/DD, MM/DD/YYYY, 'today', 'yesterday'."""
    value = value.strip().lower()
    if value == "today":
        return date.today().isoformat()
    if value == "yesterday":
        return (date.today() - timedelta(days=1)).isoformat()
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"):
        try:
            return datetime.strptime(value, fmt).date().isoformat()
        except ValueError:
            pass
    try:  # MM/DD shorthand, current year
        d = datetime.strptime(value, "%m/%d").date()
        return d.replace(year=date.today().year).isoformat()
    except ValueError:
        raise click.BadParameter(
            f"Can't parse date {value!r} (try YYYY-MM-DD, MM/DD, today, yesterday)"
        )


def get_lead(conn, lead_id: int):
    lead = conn.execute("SELECT * FROM leads WHERE id = ?", (lead_id,)).fetchone()
    if lead is None:
        raise click.ClickException(f"No lead with id {lead_id}. Try: stormtrack search <name>")
    return lead


def log_touch(conn, lead_id: int, touch_type: str, note: str) -> None:
    ts = now()
    conn.execute(
        "INSERT INTO touches (lead_id, touch_type, note, timestamp) VALUES (?, ?, ?, ?)",
        (lead_id, touch_type, note, ts),
    )
    conn.execute("UPDATE leads SET last_touch = ? WHERE id = ?", (ts, lead_id))
    conn.commit()


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, a.lower(), b.lower()).ratio()


def days_since(ts: str) -> int:
    then = datetime.strptime(ts, "%Y-%m-%d %H:%M:%S").date()
    return (date.today() - then).days


def money(value) -> str:
    return f"${value:,.0f}" if value else "—"


def is_breaching(status: str, stale_days: int) -> bool:
    """True if a lead in `status`, untouched for `stale_days`, needs a follow-up.

    Statuses without a threshold (terminal states, closed) never breach. A
    threshold of 0 is a same-day reminder: breach once a full day has passed.
    """
    threshold = db.FOLLOWUP_THRESHOLDS.get(status)
    if threshold is None:
        return False
    if threshold == 0:
        return stale_days >= 1
    return stale_days > threshold


def pipeline_stats(leads):
    """Aggregate the pipeline: per-status counts, total value, and conversion.

    `leads` is any iterable of mappings exposing "status" and "estimated_value".
    Returns (counts, values, conversions):
      counts[status]      -> int
      values[status]      -> float (sum of estimated_value, missing counts as 0)
      conversions[stage]  -> float percent of leads that reached this pipeline
                             stage and also reached the next one, or None when
                             undefined (nothing reached the stage, or it is the
                             final pipeline stage). Terminal states are omitted.
    """
    counts = {s: 0 for s in db.ALL_STATUSES}
    values = {s: 0.0 for s in db.ALL_STATUSES}
    for lead in leads:
        counts[lead["status"]] += 1
        values[lead["status"]] += lead["estimated_value"] or 0

    # A lead "reached" stage i if its current pipeline index is >= i.
    reached = [
        sum(
            1 for lead in leads
            if lead["status"] in db.PIPELINE and db.PIPELINE.index(lead["status"]) >= i
        )
        for i in range(len(db.PIPELINE))
    ]
    conversions = {}
    for i, stage in enumerate(db.PIPELINE):
        if i + 1 < len(db.PIPELINE) and reached[i]:
            conversions[stage] = 100 * reached[i + 1] / reached[i]
        else:
            conversions[stage] = None
    return counts, values, conversions


# ---------------------------------------------------------------------------
# CLI

@click.group()
@click.version_option()
def main():
    """stormtrack — storm-restoration lead pipeline, from first knock to closed deal.

    \b
    Daily loop:
      stormtrack add "Jane Doe" --address "12 Elm St" --source knock
      stormtrack touch 4 call "left VM about adjuster date"
      stormtrack status 4 claim-filed
      stormtrack followups        <- who needs attention right now
    """


@main.command()
@click.argument("name")
@click.option("--address", default="", help='Street address, e.g. "123 Elm St, OKC"')
@click.option("--phone", default="", help="Phone number")
@click.option("--email", default="", help="Email address")
@click.option("--storm-date", default=None, help="Qualifying storm date (YYYY-MM-DD, MM/DD, today)")
@click.option("--carrier", default="", help='Insurance carrier, e.g. "State Farm"')
@click.option("--claim", "claim_number", default="", help="Claim number, once filed")
@click.option("--deductible", type=float, default=None, help="Deductible amount")
@click.option("--value", "estimated_value", type=float, default=None, help="Estimated job value")
@click.option("--source", type=click.Choice(db.SOURCES), default="knock", show_default=True)
@click.option("--notes", default="", help="Freeform notes")
@click.option("--force", is_flag=True, help="Skip the duplicate check")
def add(name, address, phone, email, storm_date, carrier, claim_number,
        deductible, estimated_value, source, notes, force):
    """Add a new lead. Only NAME is required.

    Example: stormtrack add "John Smith" --address "123 Elm St" --carrier "State Farm" --storm-date 05/15
    """
    conn = db.connect()
    storm = parse_date(storm_date) if storm_date else None

    if not force:
        key = f"{name} {address}"
        for row in conn.execute("SELECT id, name, address FROM leads").fetchall():
            if similarity(key, f"{row['name']} {row['address']}") > 0.82:
                console.print(
                    f"[yellow]Possible duplicate:[/yellow] #{row['id']} "
                    f"{row['name']} — {row['address']}"
                )
                if not click.confirm("Add anyway?"):
                    raise SystemExit(1)
                break

    ts = now()
    cur = conn.execute(
        """INSERT INTO leads (name, address, phone, email, storm_date, carrier,
               claim_number, deductible, estimated_value, status, source, notes,
               created_at, last_touch)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'knocked', ?, ?, ?, ?)""",
        (name, address, phone, email, storm, carrier, claim_number,
         deductible, estimated_value, source, notes, ts, ts),
    )
    conn.commit()
    console.print(f"[green]Added lead #{cur.lastrowid}[/green] {name} — status: knocked")


@main.command()
@click.argument("lead_id", type=int)
@click.argument("new_status", type=click.Choice(db.ALL_STATUSES))
@click.option("--reason", default="", help="Required when marking a lead dead")
def status(lead_id, new_status, reason):
    """Move a lead to NEW_STATUS (warns on skipped stages, but allows them).

    Example: stormtrack status 4 adjuster-scheduled
    """
    conn = db.connect()
    lead = get_lead(conn, lead_id)

    if new_status == "dead" and not reason:
        raise click.ClickException('Marking a lead dead requires --reason "..."')

    old = lead["status"]
    if old in db.PIPELINE and new_status in db.PIPELINE:
        jump = db.PIPELINE.index(new_status) - db.PIPELINE.index(old)
        if jump > 1:
            console.print(
                f"[yellow]Heads up:[/yellow] skipping {jump - 1} stage(s) "
                f"({old} → {new_status})"
            )
        elif jump < 0:
            console.print(f"[yellow]Heads up:[/yellow] moving backward ({old} → {new_status})")

    conn.execute(
        "UPDATE leads SET status = ?, dead_reason = ? WHERE id = ?",
        (new_status, reason if new_status == "dead" else lead["dead_reason"], lead_id),
    )
    note = f"{old} → {new_status}" + (f" ({reason})" if reason else "")
    log_touch(conn, lead_id, "status-change", note)
    console.print(f"[green]#{lead_id} {lead['name']}[/green]: {old} → [bold]{new_status}[/bold]")
    if new_status == "denied":
        console.print("[dim]Denied leads can be reactivated for supplement/reinspection "
                      "with: stormtrack status <id> claim-filed[/dim]")


@main.command()
@click.argument("lead_id", type=int)
@click.argument("touch_type", type=click.Choice(db.TOUCH_TYPES))
@click.argument("note", default="")
def touch(lead_id, touch_type, note):
    """Log an interaction and bump last-touch.

    Example: stormtrack touch 4 call "left VM about adjuster date"
    """
    conn = db.connect()
    lead = get_lead(conn, lead_id)
    log_touch(conn, lead_id, touch_type, note)
    console.print(f"[green]Logged[/green] {touch_type} on #{lead_id} {lead['name']}")


@main.command()
def followups():
    """The money command: every lead breaching its staleness threshold.

    Example: stormtrack followups
    """
    conn = db.connect()
    rows = conn.execute(
        "SELECT * FROM leads WHERE status IN ({})".format(
            ",".join("?" * len(db.FOLLOWUP_THRESHOLDS))
        ),
        list(db.FOLLOWUP_THRESHOLDS),
    ).fetchall()

    breaches = []
    for lead in rows:
        threshold = db.FOLLOWUP_THRESHOLDS[lead["status"]]
        stale = days_since(lead["last_touch"])
        if is_breaching(lead["status"], stale):
            breaches.append((stale - threshold, stale, threshold, lead))

    if not breaches:
        console.print("[green]Nothing overdue. Go knock.[/green]")
        return

    breaches.sort(key=lambda item: item[0], reverse=True)
    table = Table(title=f"Follow-ups needed ({len(breaches)})")
    table.add_column("ID", justify="right")
    table.add_column("Name")
    table.add_column("Status")
    table.add_column("Days stale", justify="right")
    table.add_column("Overdue by", justify="right")
    table.add_column("Phone")

    for overdue, stale, threshold, lead in breaches:
        hot = threshold > 0 and stale >= 2 * threshold
        style = "red" if (hot or threshold == 0 and stale >= 2) else "yellow"
        table.add_row(
            str(lead["id"]), lead["name"], lead["status"],
            str(stale), f"+{overdue}d", lead["phone"] or "—",
            style=style,
        )
    console.print(table)


@main.command()
def pipeline():
    """Pipeline summary: counts, value per status, stage-to-stage conversion.

    Example: stormtrack pipeline
    """
    conn = db.connect()
    leads = conn.execute("SELECT status, estimated_value FROM leads").fetchall()
    counts, values, conversions = pipeline_stats(leads)

    table = Table(title=f"Pipeline — {len(leads)} leads")
    table.add_column("Status")
    table.add_column("Count", justify="right")
    table.add_column("Est. value", justify="right")
    table.add_column("Conversion →", justify="right")

    for stage in db.PIPELINE:
        conv = conversions[stage]
        conv_str = f"{conv:.0f}%" if conv is not None else "—"
        table.add_row(stage, str(counts[stage]), money(values[stage]), conv_str)
    for stage in db.TERMINAL:
        table.add_row(f"[dim]{stage}[/dim]", str(counts[stage]), money(values[stage]), "")
    console.print(table)


@main.command()
@click.argument("lead_id", type=int)
def show(lead_id):
    """Full lead card with complete touch history.

    Example: stormtrack show 4
    """
    conn = db.connect()
    lead = get_lead(conn, lead_id)

    body = "\n".join(
        f"[bold]{label}:[/bold] {value}"
        for label, value in [
            ("Address", lead["address"] or "—"),
            ("Phone", lead["phone"] or "—"),
            ("Email", lead["email"] or "—"),
            ("Storm date", lead["storm_date"] or "—"),
            ("Carrier", lead["carrier"] or "—"),
            ("Claim #", lead["claim_number"] or "—"),
            ("Deductible", money(lead["deductible"])),
            ("Est. value", money(lead["estimated_value"])),
            ("Source", lead["source"]),
            ("Status", f"[bold]{lead['status']}[/bold]"
                       + (f" ({lead['dead_reason']})" if lead["dead_reason"] else "")),
            ("Created", lead["created_at"]),
            ("Last touch", f"{lead['last_touch']} ({days_since(lead['last_touch'])}d ago)"),
            ("Notes", lead["notes"] or "—"),
        ]
    )
    console.print(Panel(body, title=f"#{lead['id']} — {lead['name']}"))

    touches = conn.execute(
        "SELECT * FROM touches WHERE lead_id = ? ORDER BY timestamp DESC", (lead_id,)
    ).fetchall()
    if touches:
        table = Table(title=f"Touch history ({len(touches)})")
        table.add_column("When")
        table.add_column("Type")
        table.add_column("Note")
        for t in touches:
            table.add_row(t["timestamp"], t["touch_type"], t["note"])
        console.print(table)


@main.command()
@click.argument("query")
def search(query):
    """Fuzzy search on name, address, and carrier.

    Example: stormtrack search "elm"
    """
    conn = db.connect()
    q = query.lower()
    hits = []
    for lead in conn.execute("SELECT * FROM leads").fetchall():
        haystacks = [lead["name"], lead["address"], lead["carrier"]]
        score = 0.0
        for hay in haystacks:
            hay = (hay or "").lower()
            if q in hay:
                score = max(score, 1.0)
            else:
                for word in hay.split():
                    score = max(score, similarity(q, word))
        if score >= 0.6:
            hits.append((score, lead))

    if not hits:
        console.print(f"No leads matching {query!r}")
        return
    hits.sort(key=lambda item: item[0], reverse=True)
    table = Table(title=f"Matches for {query!r}")
    for col in ("ID", "Name", "Address", "Carrier", "Status"):
        table.add_column(col)
    for _, lead in hits[:15]:
        table.add_row(str(lead["id"]), lead["name"], lead["address"],
                      lead["carrier"], lead["status"])
    console.print(table)


@main.command()
@click.option("--csv", "as_csv", is_flag=True, default=True, help="CSV format (default)")
@click.option("--out", type=click.Path(), default=None, help="Override output path")
def export(as_csv, out):
    """Dump all leads to ~/Desktop/stormtrack-export-YYYYMMDD.csv.

    Example: stormtrack export --csv
    """
    conn = db.connect()
    leads = conn.execute("SELECT * FROM leads ORDER BY id").fetchall()
    if out:
        path = Path(out).expanduser()
    else:
        desktop = Path.home() / "Desktop"
        target = desktop if desktop.is_dir() else Path.home()
        path = target / f"stormtrack-export-{date.today().strftime('%Y%m%d')}.csv"

    with open(path, "w", newline="") as fh:
        writer = csv.writer(fh)
        if leads:
            writer.writerow(leads[0].keys())
            for lead in leads:
                writer.writerow(list(lead))
    console.print(f"[green]Exported {len(leads)} leads[/green] → {path}")


@main.command()
def demo():
    """Seed 10 demo leads for testing.

    Example: stormtrack demo
    """
    conn = db.connect()
    seeds = [
        ("Marge Hutchins", "1412 NW 42nd St, Oklahoma City, OK", "knocked", "State Farm", 14500, 4),
        ("Daryl Boggs", "220 Cedar Ridge Dr, Moore, OK", "knocked", "", 12000, 1),
        ("Alma Reyes", "3105 SE 89th St, Oklahoma City, OK", "inspected", "Allstate", 18800, 3),
        ("Tom Whitaker", "808 Sunset Blvd, Yukon, OK", "claim-filed", "Farmers", 16250, 5),
        ("Priya Nair", "1717 Redbud Ln, Edmond, OK", "adjuster-scheduled", "USAA", 21400, 1),
        ("Gene Calloway", "455 Prairie View Rd, Mustang, OK", "adjuster-met", "Travelers", 19900, 2),
        ("Rosa Delgado", "2603 N Ann Arbor Ave, Oklahoma City, OK", "approved", "Liberty Mutual", 23750, 2),
        ("Hank Sorensen", "119 Dogwood Ct, Norman, OK", "contract-signed", "State Farm", 20100, 6),
        ("Bev Tallchief", "5308 S Shartel Ave, Oklahoma City, OK", "built", "Allstate", 17300, 3),
        ("Wes Fenwick", "901 Timber Creek Dr, Edmond, OK", "denied", "Farmers", 15600, 9),
    ]
    for name, address, lead_status, carrier, value, stale_days in seeds:
        ts = (datetime.now() - timedelta(days=stale_days)).strftime("%Y-%m-%d %H:%M:%S")
        cur = conn.execute(
            """INSERT INTO leads (name, address, phone, storm_date, carrier,
                   estimated_value, status, source, created_at, last_touch)
               VALUES (?, ?, '405-555-0100', ?, ?, ?, ?, 'knock', ?, ?)""",
            (name, address, (date.today() - timedelta(days=30)).isoformat(),
             carrier, value, lead_status, ts, ts),
        )
        conn.execute(
            "INSERT INTO touches (lead_id, touch_type, note, timestamp) VALUES (?, 'door', 'initial knock', ?)",
            (cur.lastrowid, ts),
        )
    conn.commit()
    console.print("[green]Seeded 10 demo leads.[/green] Try: stormtrack followups")


if __name__ == "__main__":
    main()
