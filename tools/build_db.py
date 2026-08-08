#!/usr/bin/env python3
"""Compile srimad.csv into the app's bundled, read-only gita.sqlite.

Scope: the Sanskrit mula shloka only — `counter`, `chapter`, `sutra` and
`mool_shloka`. The Hindi/English columns exist in the CSV and in the app's data
model (specs.md section 5) but are deliberately not written here yet.

srimad.csv stays the single source of truth, shared with the Hugo site. The
database is a build artifact: regenerate it, never hand-edit it.

    python3 tools/build_db.py [--csv srimad.csv] [--out <path>]
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV = ROOT / "srimad.csv"
DEFAULT_OUT = ROOT / "app" / "Gita" / "Gita" / "Resources" / "Database" / "gita.sqlite"

CONTENT_VERSION = 1

SCHEMA = """
CREATE TABLE verses (
    id       INTEGER PRIMARY KEY,   -- global position, == csv `counter`
    chapter  INTEGER NOT NULL,
    sutra    INTEGER NOT NULL,
    sanskrit TEXT    NOT NULL       -- mula shloka, line breaks preserved
);

CREATE UNIQUE INDEX idx_verses_chapter_sutra ON verses(chapter, sutra);
CREATE INDEX idx_verses_chapter ON verses(chapter);

CREATE VIRTUAL TABLE verses_fts USING fts5(
    sanskrit,
    content='verses',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
);

CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""


def normalize(text: str) -> str:
    """Trim the block but keep the shloka's internal line breaks intact.

    Line breaks are semantic here (specs.md section 8) — the reader must not
    reflow them — so only line-trailing whitespace and surrounding blank lines go.
    """
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    return "\n".join(line.rstrip() for line in lines).strip()


def read_verses(csv_path: Path) -> list[tuple[int, int, int, str]]:
    with csv_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    required = {"counter", "chapter", "sutra", "mool_shloka"}
    missing = required - set(rows[0] if rows else {})
    if missing:
        sys.exit(f"error: {csv_path} is missing column(s): {', '.join(sorted(missing))}")

    verses = []
    for line_no, row in enumerate(rows, start=2):
        shloka = normalize(row["mool_shloka"] or "")
        if not shloka:
            sys.exit(f"error: empty mool_shloka at {csv_path}:{line_no}")
        verses.append(
            (int(row["counter"]), int(row["chapter"]), int(row["sutra"]), shloka)
        )

    verses.sort(key=lambda v: (v[1], v[2]))
    return verses


def build(csv_path: Path, out_path: Path) -> None:
    verses = read_verses(csv_path)
    checksum = hashlib.sha256(csv_path.read_bytes()).hexdigest()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.unlink(missing_ok=True)

    db = sqlite3.connect(out_path)
    try:
        db.executescript(SCHEMA)
        db.executemany("INSERT INTO verses (id, chapter, sutra, sanskrit) VALUES (?, ?, ?, ?)", verses)
        db.execute("INSERT INTO verses_fts(verses_fts) VALUES ('rebuild')")
        db.executemany(
            "INSERT INTO meta (key, value) VALUES (?, ?)",
            [
                ("content_version", str(CONTENT_VERSION)),
                ("built_at", datetime.now(timezone.utc).isoformat(timespec="seconds")),
                ("source_checksum", checksum),
                ("source_file", csv_path.name),
                ("verse_count", str(len(verses))),
                ("columns", "counter,chapter,sutra,mool_shloka"),
            ],
        )
        db.commit()
        db.execute("PRAGMA optimize")
        db.execute("VACUUM")
    finally:
        db.close()

    chapters = sorted({v[1] for v in verses})
    size_kb = out_path.stat().st_size / 1024
    print(f"wrote {out_path.relative_to(ROOT)}  ({size_kb:.0f} KB)")
    print(f"  {len(verses)} verses across {len(chapters)} chapters ({chapters[0]}–{chapters[-1]})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.csv.exists():
        sys.exit(f"error: {args.csv} not found")
    build(args.csv, args.out)


if __name__ == "__main__":
    main()
