"""obj CLI — surface the exact word-for-word objection response in under 2 seconds.

Knowledge base lives in ~/objections/ (override with OBJ_KB_DIR) as plain
markdown, one file per category. On first run the bundled seed content is
copied there so the files stay human-editable and git-friendly.
"""

import os
import random
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path

import click
from rapidfuzz import fuzz
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()

SEED_DIR = Path(__file__).parent / "kb"


def kb_dir() -> Path:
    d = Path(os.environ.get("OBJ_KB_DIR", "~/objections")).expanduser()
    if not d.is_dir() or not any(d.glob("*.md")):
        d.mkdir(parents=True, exist_ok=True)
        for f in sorted(SEED_DIR.glob("*.md")):
            target = d / f.name
            if not target.exists():
                shutil.copy(f, target)
        console.print(f"[dim]Seeded objection knowledge base at {d}[/dim]")
    return d


@dataclass
class Entry:
    objection: str
    tags: list[str] = field(default_factory=list)
    category: str = ""
    reframe: str = ""
    response: str = ""
    psychology: str = ""
    source_file: str = ""

    def render(self):
        body = ""
        if self.reframe:
            body += f"[bold cyan]The Reframe[/bold cyan]\n{self.reframe}\n\n"
        body += f"[bold green]Word-for-Word Response[/bold green]\n{self.response}"
        if self.psychology:
            body += f"\n\n[bold magenta]The Psychology[/bold magenta]\n{self.psychology}"
        console.print(Panel(
            body,
            title=f'[bold]"{self.objection}"[/bold]',
            subtitle=f"{self.category}  ·  tags: {', '.join(self.tags)}",
        ))


SECTION_RE = re.compile(r"^###\s+(.+?)\s*$")

SECTION_KEYS = {
    "the reframe": "reframe",
    "word-for-word response": "response",
    "the psychology": "psychology",
}


def parse_file(path: Path) -> list[Entry]:
    """Parse one KB file. Tolerates extra whitespace and blank lines."""
    entries = []
    entry = None
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("## OBJECTION:"):
            if entry:
                entries.append(entry)
            text = stripped[len("## OBJECTION:"):].strip().strip('"')
            entry = Entry(objection=text, source_file=path.name)
            section = None
            continue
        if entry is None:
            continue

        if stripped.startswith("**Tags:**"):
            tags = stripped[len("**Tags:**"):].strip()
            entry.tags = [t.strip() for t in tags.split(",") if t.strip()]
            continue
        if stripped.startswith("**Category:**"):
            entry.category = stripped[len("**Category:**"):].strip()
            continue

        m = SECTION_RE.match(stripped)
        if m:
            section = SECTION_KEYS.get(m.group(1).strip().lower())
            continue
        if stripped == "---":
            section = None
            continue

        if section and stripped:
            current = getattr(entry, section)
            setattr(entry, section, (current + " " + stripped).strip() if current else stripped)

    if entry:
        entries.append(entry)
    return entries


def load_all() -> list[Entry]:
    entries = []
    for path in sorted(kb_dir().glob("*.md")):
        entries.extend(parse_file(path))
    return entries


def score(query: str, entry: Entry) -> float:
    """Fuzzy score across objection text, tags, and body."""
    q = query.lower()
    best = fuzz.WRatio(q, entry.objection.lower())
    for tag in entry.tags:
        best = max(best, fuzz.WRatio(q, tag.lower()))
    body = f"{entry.reframe} {entry.response} {entry.psychology}".lower()
    best = max(best, 0.85 * fuzz.partial_ratio(q, body))
    return best


@click.command(context_settings={"help_option_names": ["-h", "--help"]})
@click.argument("query", required=False)
@click.option("-l", "list_categories", is_flag=True, help="List all categories with entry counts")
@click.option("-c", "category", default=None, help="Dump all entries in a category (fuzzy matched)")
@click.option("-r", "quiz", is_flag=True, help="Random objection, response hidden — self-quiz mode")
@click.option("--add", "add_entry", is_flag=True, help="Interactively add a new entry")
@click.version_option()
def main(query, list_categories, category, quiz, add_entry):
    """Fuzzy-search the objection knowledge base.

    \b
    Examples:
      obj "deductible"       best-matching response, ready to deliver
      obj -l                 categories and entry counts
      obj -c price           review a whole category in the truck
      obj -r                 quiz yourself; Enter reveals the answer
      obj --add              append a new entry in proper format
    """
    entries = load_all()
    if not entries:
        raise click.ClickException(f"No entries found in {kb_dir()}")

    if list_categories:
        table = Table(title=f"Objection KB — {len(entries)} entries")
        table.add_column("File")
        table.add_column("Category")
        table.add_column("Entries", justify="right")
        by_file: dict[str, list[Entry]] = {}
        for e in entries:
            by_file.setdefault(e.source_file, []).append(e)
        for fname, items in sorted(by_file.items()):
            table.add_row(fname, items[0].category, str(len(items)))
        console.print(table)
        return

    if category:
        matches = [e for e in entries
                   if fuzz.partial_ratio(category.lower(), e.category.lower()) > 75
                   or fuzz.partial_ratio(category.lower(), e.source_file.lower()) > 75]
        if not matches:
            raise click.ClickException(f"No category matching {category!r} — see obj -l")
        console.print(f"[bold]{matches[0].category}[/bold] — {len(matches)} entries\n")
        for e in matches:
            e.render()
        return

    if quiz:
        entry = random.choice(entries)
        console.print(Panel(f'[bold]"{entry.objection}"[/bold]',
                            title="Say your answer OUT LOUD first"))
        try:
            input("Press Enter to reveal... ")
        except (EOFError, KeyboardInterrupt):
            console.print()
        entry.render()
        return

    if add_entry:
        do_add()
        return

    if not query:
        click.echo(click.get_current_context().get_help())
        return

    ranked = sorted(entries, key=lambda e: score(query, e), reverse=True)
    top, runners = ranked[0], ranked[1:3]
    top.render()
    if runners:
        console.print("[dim]Also close: " + "  |  ".join(
            f'"{e.objection[:48]}" ({e.source_file})' for e in runners
        ) + "[/dim]")


def do_add():
    """Interactive prompt that appends a properly formatted entry."""
    d = kb_dir()
    files = sorted(d.glob("*.md"))
    console.print("[bold]Which file?[/bold]")
    for i, f in enumerate(files, 1):
        console.print(f"  {i}. {f.name}")
    console.print(f"  {len(files) + 1}. <new file>")
    choice = click.prompt("Number", type=click.IntRange(1, len(files) + 1))
    if choice == len(files) + 1:
        name = click.prompt("New filename (e.g. hoa-objections)").strip()
        target = d / f"{re.sub(r'[^a-z0-9-]+', '-', name.lower()).strip('-')}.md"
        target.touch()
    else:
        target = files[choice - 1]

    objection = click.prompt("Objection (their exact words)").strip()
    tags = click.prompt("Tags (comma separated)").strip()
    existing = parse_file(target)
    default_cat = existing[0].category if existing else target.stem.replace("-", " ").title()
    cat = click.prompt("Category", default=default_cat).strip()
    reframe = click.prompt("The Reframe").strip()
    response = click.prompt("Word-for-Word Response").strip()
    psychology = click.prompt("The Psychology", default="").strip()

    block = (
        f'\n## OBJECTION: "{objection}"\n'
        f"**Tags:** {tags}\n"
        f"**Category:** {cat}\n\n"
        f"### The Reframe\n{reframe}\n\n"
        f"### Word-for-Word Response\n{response}\n\n"
    )
    if psychology:
        block += f"### The Psychology\n{psychology}\n\n"
    block += "---\n"

    with open(target, "a", encoding="utf-8") as fh:
        fh.write(block)
    console.print(f"[green]Added to {target}[/green]")


if __name__ == "__main__":
    main()
