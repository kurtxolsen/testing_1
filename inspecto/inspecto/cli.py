"""inspecto — turn a folder of damage photos + notes.txt into a carrier-ready,
AQE-branded PDF inspection report.

    inspecto "~/Documents/AQE Clients/Smith, John — 123 Elm St" --inspector "Kurt Olsen"

Works on a Spec-2 client folder (photos under "01 Photos/**") or any plain
folder of images with a notes.txt beside them.
"""

import io
import re
import tempfile
from datetime import date
from pathlib import Path

import click
from PIL import Image, ImageOps
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import letter
from reportlab.lib.utils import ImageReader, simpleSplit
from reportlab.pdfgen import canvas as pdfcanvas
from rich.console import Console

console = Console()

# ---------------------------------------------------------------------------
# Branding — edit these to restyle every report.
COMPANY = "American Quality Exteriors"
TAGLINE = "Storm Restoration Specialists"
CONTACT = "americanqualityexteriors.com — (918) 510-6053"
PRIMARY = HexColor("#1B3A5C")  # navy
ACCENT = HexColor("#E8A020")   # gold

# ---------------------------------------------------------------------------
# Terminology upgrades: casual field notes -> insurance language.
# Longest phrases first so "hail hits" wins over "hail". Trivially extendable.
TERMINOLOGY = {
    "hail hits": "hail impact bruising with granular displacement",
    "hail bruising": "hail impact bruising with granular displacement",
    "bruising": "impact bruising with granular displacement",
    "dents": "soft metal collateral damage",
    "dented": "exhibiting soft metal collateral damage on",
    "dings": "soft metal collateral damage",
    "creased": "wind-lifted and creased, compromising seal integrity on",
    "creasing": "wind-lift creasing compromising seal integrity",
    "missing shingles": "wind-displaced shingle loss exposing underlayment",
    "granule loss": "granular displacement exposing the asphalt substrate",
    "cracked": "fractured, consistent with impact-related mat damage:",
    "leak": "active moisture intrusion",
    "water stain": "interior moisture staining consistent with roof-system failure",
    "soft metals": "soft metal components (gutters, downspouts, flashings, AC fins)",
    "torn": "displaced and torn, compromising the weather barrier:",
}

MAX_PHOTO_WIDTH = 1600  # px — keeps 20-photo reports comfortably under ~10MB

PAGE_W, PAGE_H = letter
MARGIN = 54

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".heic"}

try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
    HEIC_OK = True
except ImportError:
    HEIC_OK = False


# ---------------------------------------------------------------------------
# notes.txt parsing

FIELDS = ["CLIENT", "ADDRESS", "CARRIER", "CLAIM", "STORM DATE", "ROOF TYPE",
          "INSPECTOR", "DATE"]


def parse_notes(path: Path | None) -> dict:
    data = {"damage": [], "captions": {}}
    if path is None or not path.exists():
        return data
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        upper = line.upper()
        if upper.startswith("DAMAGE:"):
            section = "damage"
            continue
        if upper.startswith("PHOTOS:"):
            section = "photos"
            continue
        matched = next((f for f in FIELDS if upper.startswith(f + ":")), None)
        if matched:
            data[matched.lower().replace(" ", "_")] = line.split(":", 1)[1].strip()
            section = None
            continue
        if section == "damage" and line.startswith("-"):
            data["damage"].append(line.lstrip("- ").strip())
        elif section == "photos" and ":" in line:
            fname, caption = line.split(":", 1)
            data["captions"][fname.strip().lower()] = caption.strip()
    return data


# Single pass, longest phrase wins — never re-matches inside replacement text.
_TERM_RE = re.compile(
    "|".join(re.escape(k) for k in sorted(TERMINOLOGY, key=len, reverse=True)),
    re.IGNORECASE,
)


def upgrade_terminology(text: str) -> str:
    return _TERM_RE.sub(lambda m: TERMINOLOGY[m.group(0).lower()], text)


# ---------------------------------------------------------------------------
# scope derivation

SCOPE_RULES = [
    (r"hail|bruis|impact|granul",
     "Full replacement of affected slopes per manufacturer repairability guidelines"),
    (r"gutter|downspout|soft metal|dent",
     "Replace gutters and downspouts; comb AC condenser fins"),
    (r"wind|creas|missing|displac",
     "Replace wind-damaged shingles and ridge cap; verify seal integrity of adjacent courses"),
    (r"leak|moisture|stain|interior",
     "Interior remediation: seal, texture and repaint affected ceilings after roof completion"),
    (r"flashing|pipe jack|vent",
     "Replace all penetration flashings, pipe jacks and vents during re-roof"),
]

STANDARD_SCOPE = [
    "Install new underlayment, drip edge and ice & water barrier per current IRC code",
    "ITEL / shingle-matching analysis if repair scope is proposed (placeholder — attach report)",
]


def derive_scope(damage_lines: list[str]) -> list[str]:
    text = " ".join(damage_lines).lower()
    items = [item for pattern, item in SCOPE_RULES if re.search(pattern, text)]
    if not items:
        items.append("Further evaluation recommended — see photo documentation")
    return items + STANDARD_SCOPE


# ---------------------------------------------------------------------------
# photo handling

def find_photos(folder: Path) -> list[Path]:
    roots = [folder / "01 Photos", folder]
    seen, photos = set(), []
    for root in roots:
        if not root.is_dir():
            continue
        for p in sorted(root.rglob("*")):
            if p.suffix.lower() in IMAGE_EXTS and p.name.lower() not in seen:
                if p.suffix.lower() == ".heic" and not HEIC_OK:
                    console.print(f"[yellow]Skipping {p.name} — install pillow-heif "
                                  f"for HEIC support[/yellow]")
                    continue
                photos.append(p)
                seen.add(p.name.lower())
    return photos


def prepare_image(path: Path, tmpdir: Path) -> tuple[Path, float]:
    """EXIF-correct, downscale, recompress. Returns (jpeg path, aspect ratio)."""
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im)
        if im.width > MAX_PHOTO_WIDTH:
            im = im.resize(
                (MAX_PHOTO_WIDTH, round(im.height * MAX_PHOTO_WIDTH / im.width)),
                Image.LANCZOS,
            )
        if im.mode != "RGB":
            im = im.convert("RGB")
        out = tmpdir / (path.stem + ".jpg")
        im.save(out, "JPEG", quality=82)
        return out, im.height / im.width


# ---------------------------------------------------------------------------
# PDF building blocks

def wrap(text, font, size, width):
    return simpleSplit(text, font, size, width)


def draw_watermark(c):
    c.saveState()
    c.setFillColor(HexColor("#C8C8C8"))
    c.setFont("Helvetica-Bold", 90)
    c.translate(PAGE_W / 2, PAGE_H / 2)
    c.rotate(45)
    c.drawCentredString(0, 0, "DRAFT")
    c.restoreState()


def draw_footer(c, page_label: str):
    c.setFillColor(PRIMARY)
    c.setFont("Helvetica", 8)
    c.drawString(MARGIN, 30, f"{COMPANY} — Inspection Report")
    c.drawRightString(PAGE_W - MARGIN, 30, page_label)


def cover_page(c, notes, inspector, draft):
    c.setFillColor(PRIMARY)
    c.rect(0, PAGE_H - 170, PAGE_W, 170, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 26)
    c.drawString(MARGIN, PAGE_H - 78, COMPANY)
    c.setFillColor(ACCENT)
    c.setFont("Helvetica", 12)
    c.drawString(MARGIN, PAGE_H - 98, TAGLINE)
    c.setFillColor(white)
    c.setFont("Helvetica", 9.5)
    c.drawString(MARGIN, PAGE_H - 130, CONTACT)

    c.setFillColor(ACCENT)
    c.setFont("Helvetica-Bold", 20)
    c.drawString(MARGIN, PAGE_H - 240, "ROOF INSPECTION REPORT")

    rows = [
        ("Client", notes.get("client", "Not documented")),
        ("Property", notes.get("address", "Not documented")),
        ("Carrier", notes.get("carrier", "Not documented")),
        ("Claim #", notes.get("claim", "Not documented")),
        ("Storm date", notes.get("storm_date", "Not documented")),
        ("Roof type", notes.get("roof_type", "Not documented")),
        ("Inspection date", notes.get("date") or f"{date.today():%B %d, %Y}"),
        ("Inspector", inspector or notes.get("inspector", "Not documented")),
    ]
    y = PAGE_H - 290
    for label, value in rows:
        c.setFillColor(PRIMARY)
        c.setFont("Helvetica-Bold", 11)
        c.drawString(MARGIN, y, f"{label}:")
        c.setFont("Helvetica", 11)
        c.drawString(MARGIN + 110, y, value)
        y -= 20

    if draft:
        draw_watermark(c)
    draw_footer(c, "Cover")
    c.showPage()


def summary_page(c, notes, draft):
    c.setFillColor(PRIMARY)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(MARGIN, PAGE_H - 72, "Damage Summary")

    damage = notes["damage"]
    if damage:
        upgraded = [upgrade_terminology(d) for d in damage]
        narrative = (
            f"On {notes.get('date') or f'{date.today():%B %d, %Y}'}, a physical inspection "
            f"of the roofing system and exterior elevations at "
            f"{notes.get('address', 'the subject property')} was performed following the "
            f"{notes.get('storm_date', 'reported')} storm event. The inspection documented "
            "storm-related damage consistent with hail and/or wind exposure, including: "
            + "; ".join(upgraded) + ". "
            "The observed damage pattern — random distribution across exposures with "
            "corroborating collateral damage to soft metal components — is consistent with "
            "storm impact rather than mechanical causes, foot traffic, or normal weathering."
        )
    else:
        narrative = ("Damage observations were not documented in the field notes. "
                     "Refer to the photo documentation on the following pages.")

    y = PAGE_H - 104
    c.setFillColor(PRIMARY)
    c.setFont("Helvetica", 10.5)
    for line in wrap(narrative, "Helvetica", 10.5, PAGE_W - 2 * MARGIN):
        c.drawString(MARGIN, y, line)
        y -= 15

    if damage:
        y -= 12
        c.setFont("Helvetica-Bold", 12)
        c.drawString(MARGIN, y, "Documented conditions")
        y -= 18
        c.setFont("Helvetica", 10.5)
        for item in damage:
            for i, line in enumerate(wrap(upgrade_terminology(item), "Helvetica", 10.5,
                                          PAGE_W - 2 * MARGIN - 14)):
                c.drawString(MARGIN + (0 if i == 0 else 14), y, ("•  " if i == 0 else "") + line)
                y -= 15
            y -= 3

    if draft:
        draw_watermark(c)
    draw_footer(c, "Damage Summary")
    c.showPage()


def photo_pages(c, photos, captions, tmpdir, draft):
    cell_w = (PAGE_W - 2 * MARGIN - 20) / 2
    cell_h = (PAGE_H - 150 - 20) / 2
    caption_h = 26
    total = len(photos)

    for start in range(0, total, 4):
        c.setFillColor(PRIMARY)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(MARGIN, PAGE_H - 60, "Photo Documentation")
        for i, photo in enumerate(photos[start:start + 4]):
            n = start + i + 1
            col, row = i % 2, i // 2
            x = MARGIN + col * (cell_w + 20)
            top = PAGE_H - 84 - row * (cell_h + 20)

            jpeg, aspect = prepare_image(photo, tmpdir)
            img_h = cell_h - caption_h
            w, h = cell_w, cell_w * aspect
            if h > img_h:
                w, h = img_h / aspect, img_h
            c.drawImage(ImageReader(str(jpeg)), x + (cell_w - w) / 2, top - h,
                        width=w, height=h)

            caption = captions.get(photo.name.lower(),
                                   f"Documented damage — {photo.name}")
            # Caption bar sits flush under the rendered image, not the cell.
            bar_top = top - h
            c.setFillColor(PRIMARY)
            c.rect(x, bar_top - caption_h, cell_w, caption_h, fill=1, stroke=0)
            c.setFillColor(white)
            c.setFont("Helvetica", 7.5)
            lines = wrap(f"Photo {n} of {total} — {caption}", "Helvetica", 7.5, cell_w - 12)
            ty = bar_top - 11
            for line in lines[:2]:
                c.drawString(x + 6, ty, line)
                ty -= 9.5
        if draft:
            draw_watermark(c)
        draw_footer(c, f"Photos {start + 1}–{min(start + 4, total)} of {total}")
        c.showPage()


def scope_page(c, notes, draft):
    c.setFillColor(PRIMARY)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(MARGIN, PAGE_H - 72, "Recommended Scope of Repairs")

    y = PAGE_H - 106
    c.setFont("Helvetica", 10.5)
    for item in derive_scope(notes["damage"]):
        for i, line in enumerate(wrap(item, "Helvetica", 10.5, PAGE_W - 2 * MARGIN - 24)):
            if i == 0:
                c.rect(MARGIN, y - 2, 9, 9, fill=0, stroke=1)
            c.drawString(MARGIN + 18, y, line)
            y -= 15
        y -= 6

    y -= 30
    c.setFont("Helvetica-Bold", 11)
    c.drawString(MARGIN, y, "Acknowledgment")
    y -= 30
    c.setFont("Helvetica", 10)
    c.line(MARGIN, y, MARGIN + 200, y)
    c.drawString(MARGIN, y - 13, "Homeowner signature / date")
    c.line(PAGE_W - MARGIN - 200, y, PAGE_W - MARGIN, y)
    c.drawString(PAGE_W - MARGIN - 200, y - 13, "Inspector signature / date")

    if draft:
        draw_watermark(c)
    draw_footer(c, "Recommended Scope")
    c.showPage()


# ---------------------------------------------------------------------------

@click.command(context_settings={"help_option_names": ["-h", "--help"]})
@click.argument("folder", type=click.Path(exists=True, file_okay=False))
@click.option("--inspector", default="", help="Inspector name for the cover page")
@click.option("--draft", is_flag=True, help="Add a diagonal DRAFT watermark to every page")
@click.option("--out", type=click.Path(), default=None, help="Override output path")
@click.version_option()
def main(folder, inspector, draft, out):
    """Generate a branded PDF inspection report from FOLDER.

    Example: inspecto "~/Documents/AQE Clients/Smith, John — 123 Elm St" --inspector "Kurt Olsen"
    """
    folder = Path(folder).expanduser()
    notes = parse_notes(folder / "notes.txt" if (folder / "notes.txt").exists() else None)
    photos = find_photos(folder)
    if not photos:
        console.print("[yellow]No photos found — generating a report without a "
                      "photo section.[/yellow]")

    if out:
        out_path = Path(out).expanduser()
    else:
        docs = folder / "02 Insurance Docs"
        target = docs if docs.is_dir() else folder
        out_path = target / f"Inspection Report — {date.today():%Y-%m-%d}.pdf"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    c = pdfcanvas.Canvas(str(out_path), pagesize=letter)
    with tempfile.TemporaryDirectory() as tmp:
        cover_page(c, notes, inspector, draft)
        summary_page(c, notes, draft)
        if photos:
            photo_pages(c, photos, notes["captions"], Path(tmp), draft)
        scope_page(c, notes, draft)
        c.save()

    size_mb = out_path.stat().st_size / 1e6
    console.print(f"[green]Report ready[/green] ({len(photos)} photos, "
                  f"{size_mb:.1f} MB) → {out_path}")


if __name__ == "__main__":
    main()
