#!/usr/bin/env python3
# Vendored verbatim from the docs-health skill
# (~/.config/crush/skills/docs-health/assets/check-rows.py) so the
# annotation gates run in CI without a skill checkout. Upstream is
# canonical — when the skill version changes, re-vendor and note it
# here. Wired into `nix flake check` via check-docs-annotations.sh.
"""Per-row completeness checker for annotate passes.

Usage: check-rows.py <markdown-file>...
Verifies, per markdown table, that every data row is uniformly struck or
uniformly untouched:

  COMPLETE  every cell of every data row carries strikethrough (the
            annotate-rows.py marker format — marker inside the first
            struck cell — counts as struck)
  UNTOUCHED no data row carries any ~~
  PARTIAL   a row mixes struck and unstruck cells, or some rows of the
            table are struck while others are not — the planted-miss class
            (the 2026-09-16 F12.3 miss shipped because nothing counted
            struck rows against table rows)

Header and separator rows are exempt. Tildes inside inline code spans (a
literal `~~...~~` in a cell) never count as strikethrough, mirroring the
annotate-rows.py guard fix of the same date.

Exit 0 when no table contains a PARTIAL row; exit 1 with the offending
rows listed otherwise. Rows a pass deliberately leaves open (e.g. f-items
kept for later) will surface here — judge and report them, don't hide them.
"""

import re
import sys
from pathlib import Path


def outside_code_spans(text: str) -> str:
    without_double = re.sub(r"``[^`]+``", "", text)

    return re.sub(r"`[^`]*`", "", without_double)


def is_separator(line: str) -> bool:
    cells = [c.strip() for c in line.strip().strip("|").split("|")]

    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", c) for c in cells)


def classify_row(line: str) -> str:
    """STRUCK / CLEAN / PARTIAL for one table data row.

    A cell counts as struck when it carries strikethrough outside code
    spans — the annotator's format wraps every cell and appends the marker
    INSIDE the first cell (`~~task~~ done at `hash``), so first cells don't
    end with ~~; requiring containment, not full wrapping, accepts both the
    marker format and plain `~~cell~~` wrapping."""
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    states = ["~~" in outside_code_spans(cell) for cell in cells]

    if all(states):
        return "STRUCK"
    if not any(states):
        return "CLEAN"

    return "PARTIAL"


def tables(lines: list[str]):
    block: list[tuple[int, str]] = []

    for i, line in enumerate(lines, start=1):
        if line.lstrip().startswith("|"):
            block.append((i, line))
            continue
        if block:
            yield block
            block = []
    if block:
        yield block


def check_file(path: Path) -> int:
    lines = path.read_text().splitlines()
    problems: list[str] = []

    for block in tables(lines):
        data = [(no, line) for no, line in block if not is_separator(line)]
        if len(data) < 2:  # header + nothing to check
            continue

        header_no = data[0][0]
        classified = [(no, line, classify_row(line)) for no, line in data[1:]]
        struck_rows = sum(1 for _, _, state in classified if state == "STRUCK")

        partial = [(no, line) for no, line, state in classified if state == "PARTIAL"]
        mixed_table = 0 < struck_rows < len(classified)

        if partial or mixed_table:
            problems.append(
                f"{path.name}: table at line {header_no} INCOMPLETE "
                f"({struck_rows}/{len(classified)} rows struck)"
            )
            for no, line in partial:
                problems.append(f"  line {no}: PARTIAL row: {line[:100]}")
            if mixed_table and not partial:
                offenders = [
                    (no, state) for no, _, state in classified if state != "STRUCK"
                ]
                for no, state in offenders:
                    problems.append(f"  line {no}: {state} row in a struck table")

    for problem in problems:
        print(problem)

    return 1 if problems else 0


def main() -> int:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)

    failures = 0
    for arg in sys.argv[1:]:
        failures |= check_file(Path(arg))

    if not failures:
        print(f"check-rows: {len(sys.argv) - 1} file(s) complete")

    return failures


if __name__ == "__main__":
    raise SystemExit(main())
