#!/usr/bin/env python3
"""Enrich the Gita's shlokas with Gemini.

Reads the Sanskrit from the built `gita.sqlite` and asks Gemini for, per verse:
IAST transliteration, a Hindi translation, an English translation, a short
meaning in each language, and word-by-word meanings in each language. Results
land in `enriched.sqlite` at the repository root — the same "intermediate data
file lives at the root" convention as `srimad.csv`.

Everything except the Sanskrit comes from Gemini. The Hindi and English
translations that already sit in `srimad.csv` are never read or sent; the only
input to the model is the mula shloka itself.

Column shape and the word-by-word JSON format mirror RigVeda's
`enriched_mantras` table.

Runs `asyncio` with five requests in flight at a time (`--concurrency`). Resumable: a verse that
already has a row is skipped, so an interrupted run is picked up by rerunning.

    export GEMINI_API_KEY=...
    .venv/bin/python tools/enrich.py                 # one verse, printed for review
    .venv/bin/python tools/enrich.py --limit 10
    .venv/bin/python tools/enrich.py --all           # all 701
    .venv/bin/python tools/enrich.py --all --force   # redo rows already done
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

from google import genai
from google.genai import types
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DB = ROOT / "app" / "Gita" / "Gita" / "Resources" / "Database" / "gita.sqlite"
OUTPUT_DB = ROOT / "enriched.sqlite"

DEFAULT_MODEL = "gemini-2.5-pro"
DEFAULT_CONCURRENCY = 5
MAX_ATTEMPTS = 4

# A 429 usually means "slow down" and is worth retrying. These mean the account
# is out of money, which no amount of backoff will fix — fail the whole run at
# once rather than burning four attempts on each of 700 verses.
FATAL_MARKERS = ("prepayment credits are depleted", "billing", "PERMISSION_DENIED", "API key not valid")

SCHEMA = """
CREATE TABLE IF NOT EXISTS enriched_verses (
    id                   INTEGER PRIMARY KEY,   -- matches verses.id in gita.sqlite
    chapter              INTEGER NOT NULL,
    sutra                INTEGER NOT NULL,
    sanskrit             TEXT    NOT NULL,
    transliteration      TEXT    NOT NULL,      -- IAST
    hindi_translation    TEXT    NOT NULL,
    english_translation  TEXT    NOT NULL,
    hindi_meaning        TEXT    NOT NULL,
    english_meaning      TEXT    NOT NULL,
    word_by_word_hindi   TEXT    NOT NULL,      -- JSON [{"w":…,"m":…}, …]
    word_by_word_english TEXT    NOT NULL,      -- JSON [{"w":…,"m":…}, …]
    model                TEXT    NOT NULL,
    updated_at           TEXT    NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_enriched_chapter_sutra
    ON enriched_verses(chapter, sutra);
"""

TEXT_FIELDS = [
    "sanskrit", "transliteration", "hindi_translation", "english_translation",
    "hindi_meaning", "english_meaning", "word_by_word_hindi", "word_by_word_english",
]


class WordMeaning(BaseModel):
    """One word of the shloka and its gloss. Key names match RigVeda's JSON."""

    w: str = Field(description="The word as it appears in the shloka.")
    m: str = Field(description="Its meaning in this entry's language.")


class Enrichment(BaseModel):
    """What we ask Gemini for, and what we insist on getting back."""

    transliteration: str = Field(
        description="IAST transliteration of the Sanskrit, with diacritics, "
        "line structure matching the shloka."
    )
    hindi_translation: str = Field(
        description="Faithful, literal translation of the shloka into Hindi (Devanagari)."
    )
    english_translation: str = Field(
        description="Faithful, literal translation of the shloka into English."
    )
    hindi_meaning: str = Field(
        description="Two to four sentences in Hindi explaining the verse's meaning "
        "and its place in the surrounding dialogue."
    )
    english_meaning: str = Field(
        description="Two to four sentences in English explaining the verse's meaning "
        "and its place in the surrounding dialogue."
    )
    word_by_word_hindi: list[WordMeaning] = Field(
        description="Every word of the shloka in order, in Devanagari, each with its "
        "Hindi meaning. Covers the whole verse — no word skipped."
    )
    word_by_word_english: list[WordMeaning] = Field(
        description="Every word of the shloka in order, in IAST, each with its "
        "English meaning. Same words, same order, as word_by_word_hindi."
    )


# Everything invariant lives in the system instruction, and the only thing that
# changes between the 701 calls is the verse below. Gemini 2.5 caches on a common
# request prefix, so an unchanging prefix is what makes caching possible at all —
# interpolating the verse into a long prompt would defeat it on every call.
#
# Caching is not free to earn: 2.5 models only cache a prefix above a minimum
# token count. The run reports how many tokens were actually served from cache,
# so this is measured rather than assumed.
SYSTEM_INSTRUCTION = """You are a Sanskrit scholar working on the Bhagavad Gita.

For each shloka you are given, provide exactly these fields:

1. transliteration — the Sanskrit in IAST with correct diacritics (a i u r n ~n t d n s s h m with their proper marks: ā ī ū ṛ ṅ ñ ṭ ḍ ṇ ś ṣ ḥ ṃ).
   Mirror the line structure of the shloka. Never include the trailing ।।chapter.verse।। marker.
2. hindi_translation — a faithful, literal Hindi translation in Devanagari.
3. english_translation — a faithful, literal English translation.
4. hindi_meaning — 2-4 sentences of explanation in Hindi.
5. english_meaning — 2-4 sentences of explanation in English.
6. word_by_word_hindi — the shloka split into its words, in the order they appear,
   each word in Devanagari with its Hindi meaning. Split sandhi and compounds into
   their constituent words the way a padaccheda would. Cover every word; skip none.
7. word_by_word_english — the same words, in the same order and the same count,
   each word in IAST with its English meaning.

Translate only what the verse says. Do not add interpretation to the translations
themselves — reserve commentary for the meaning fields. Keep proper nouns
(Arjuna, Krishna, Kurukshetra, Sanjaya, Dhritarashtra) recognisable. Return no
markdown, no verse numbers, and no preamble.
"""

PROMPT = """Verse {chapter}.{sutra}:

{sanskrit}
"""


# --------------------------------------------------------------------------- io


def open_output() -> sqlite3.Connection:
    db = sqlite3.connect(OUTPUT_DB)
    db.executescript(SCHEMA)

    # Additive migration: a database written by an earlier version of this script
    # is missing the newer columns. Add them rather than making the user delete
    # work already paid for.
    existing = {row[1] for row in db.execute("PRAGMA table_info(enriched_verses)")}
    for column in ("word_by_word_hindi", "word_by_word_english"):
        if column not in existing:
            db.execute(f"ALTER TABLE enriched_verses ADD COLUMN {column} TEXT NOT NULL DEFAULT ''")
            print(f"note: added missing column {column}; rerun with --force to fill it")

    db.commit()
    return db


def load_pending(db: sqlite3.Connection, limit: int | None, force: bool) -> list[dict]:
    if not SOURCE_DB.exists():
        sys.exit(f"error: {SOURCE_DB} not found — run tools/build_db.py first")

    source = sqlite3.connect(f"file:{SOURCE_DB}?mode=ro", uri=True)
    source.row_factory = sqlite3.Row
    verses = [dict(row) for row in source.execute(
        "SELECT id, chapter, sutra, sanskrit FROM verses ORDER BY chapter, sutra"
    )]
    source.close()

    if not force:
        done = {row[0] for row in db.execute("SELECT id FROM enriched_verses")}
        verses = [v for v in verses if v["id"] not in done]

    return verses if limit is None else verses[:limit]


def save(db: sqlite3.Connection, verse: dict, result: Enrichment, model: str) -> None:
    def as_json(words: list[WordMeaning]) -> str:
        # ensure_ascii=False keeps Devanagari readable in the file rather than
        # storing it as \uXXXX escapes.
        return json.dumps([w.model_dump() for w in words], ensure_ascii=False)

    db.execute(
        """INSERT OR REPLACE INTO enriched_verses
           (id, chapter, sutra, sanskrit, transliteration, hindi_translation,
            english_translation, hindi_meaning, english_meaning,
            word_by_word_hindi, word_by_word_english, model, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            verse["id"], verse["chapter"], verse["sutra"], verse["sanskrit"],
            result.transliteration, result.hindi_translation,
            result.english_translation, result.hindi_meaning, result.english_meaning,
            as_json(result.word_by_word_hindi), as_json(result.word_by_word_english),
            model, datetime.now(timezone.utc).isoformat(timespec="seconds"),
        ),
    )
    db.commit()


class QuotaExhausted(Exception):
    """Billing or credentials are broken — retrying cannot help."""


# ------------------------------------------------------------------------ model


async def enrich_one(
    client: genai.Client,
    model: str,
    verse: dict,
    semaphore: asyncio.Semaphore,
) -> tuple[dict, Enrichment | None, str | None, dict]:
    """One verse, retried with backoff. Returns (verse, result, error, usage)."""
    prompt = PROMPT.format(
        chapter=verse["chapter"], sutra=verse["sutra"], sanskrit=verse["sanskrit"]
    )

    async with semaphore:
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                response = await client.aio.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        response_mime_type="application/json",
                        response_schema=Enrichment,
                        temperature=0.2,
                    ),
                )
                # `.parsed` is None when the response fails schema validation —
                # the SDK swallows the ValidationError rather than raising, so an
                # unchecked `.parsed` would silently write empty rows.
                if isinstance(response.parsed, Enrichment):
                    meta = response.usage_metadata
                    usage = {
                        "prompt": getattr(meta, "prompt_token_count", 0) or 0,
                        "cached": getattr(meta, "cached_content_token_count", 0) or 0,
                        "output": getattr(meta, "candidates_token_count", 0) or 0,
                    }
                    return verse, response.parsed, None, usage
                raise ValueError(f"unparseable response: {(response.text or '')[:200]}")
            except Exception as exc:  # noqa: BLE001 — retry anything transient
                message = str(exc)
                if any(marker in message for marker in FATAL_MARKERS):
                    raise QuotaExhausted(message) from exc
                if attempt == MAX_ATTEMPTS:
                    return verse, None, f"{type(exc).__name__}: {exc}", {}
                await asyncio.sleep(2 ** attempt)

    return verse, None, "unreachable", {}


async def run(model: str, limit: int | None, force: bool, concurrency: int) -> int:
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        sys.exit("error: set GEMINI_API_KEY (or GOOGLE_API_KEY)")

    db = open_output()
    pending = load_pending(db, limit, force)
    if not pending:
        print("nothing to do — every verse is already enriched (use --force to redo)")
        return 0

    print(f"enriching {len(pending)} verse(s) with {model}, {concurrency} at a time")

    client = genai.Client(api_key=api_key)
    semaphore = asyncio.Semaphore(concurrency)
    tasks = [
        asyncio.create_task(enrich_one(client, model, verse, semaphore))
        for verse in pending
    ]

    done_count = 0
    failures: list[tuple[dict, str]] = []
    tokens = {"prompt": 0, "cached": 0, "output": 0}
    try:
        for future in asyncio.as_completed(tasks):
            verse, result, error, usage = await future
            if result is None:
                failures.append((verse, error or "unknown"))
                print(f"  ✗ {verse['chapter']}.{verse['sutra']}  {error}")
                continue
            save(db, verse, result, model)
            done_count += 1
            for key in tokens:
                tokens[key] += usage.get(key, 0)
            print(f"  ✓ {verse['chapter']}.{verse['sutra']}  ({done_count}/{len(pending)})")
    except QuotaExhausted as exc:
        for task in tasks:
            task.cancel()
        db.close()
        print(f"\nstopped: {exc}")
        print(f"{done_count} verse(s) saved before stopping; rerun once billing is sorted")
        return 2

    db.close()

    if tokens["prompt"]:
        share = 100 * tokens["cached"] / tokens["prompt"]
        print(
            f"\ntokens: {tokens['prompt']:,} prompt "
            f"({tokens['cached']:,} served from cache, {share:.0f}%), "
            f"{tokens['output']:,} output"
        )
        if not tokens["cached"]:
            print("note: nothing was cached — the shared prefix is below this "
                  "model's minimum cacheable size")

    print(f"\n{done_count} enriched, {len(failures)} failed → {OUTPUT_DB.name}")
    if failures:
        print("rerun to retry the failures; completed verses are skipped")
    return 1 if failures and done_count == 0 else 0


# ------------------------------------------------------------------------- review


def show(chapter: int | None = None, sutra: int | None = None) -> None:
    """Print stored rows in full, so a first run can actually be inspected."""
    if not OUTPUT_DB.exists():
        sys.exit(f"error: {OUTPUT_DB} not found — run an enrichment first")

    db = sqlite3.connect(OUTPUT_DB)
    db.row_factory = sqlite3.Row
    if chapter and sutra:
        rows = db.execute(
            "SELECT * FROM enriched_verses WHERE chapter = ? AND sutra = ?",
            (chapter, sutra),
        ).fetchall()
    else:
        rows = db.execute(
            "SELECT * FROM enriched_verses ORDER BY chapter, sutra LIMIT 3"
        ).fetchall()

    for row in rows:
        print("=" * 72)
        print(f"  {row['chapter']}.{row['sutra']}   model={row['model']}   {row['updated_at']}")
        print("=" * 72)
        for field in TEXT_FIELDS:
            value = row[field]
            if not (value or "").strip():
                print(f"\n--- {field}   <<< EMPTY ---")
                continue
            if field.startswith("word_by_word"):
                words = json.loads(value)
                print(f"\n--- {field}  ({len(words)} words) ---")
                for entry in words:
                    print(f"    {entry['w']:<24} {entry['m']}")
            else:
                print(f"\n--- {field} ---\n{value}")
        print()
    db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--limit", type=int, default=1,
                        help="how many verses to enrich this run (default 1)")
    parser.add_argument("--all", action="store_true", help="enrich every remaining verse")
    parser.add_argument("--force", action="store_true", help="redo verses already stored")
    parser.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY,
                        help=f"requests in flight (default {DEFAULT_CONCURRENCY})")
    parser.add_argument("--show", nargs="*", metavar=("CHAPTER", "SUTRA"),
                        help="print stored rows instead of calling the API")
    args = parser.parse_args()

    if args.show is not None:
        chapter, sutra = (int(args.show[0]), int(args.show[1])) if len(args.show) == 2 else (None, None)
        show(chapter, sutra)
        return

    limit = None if args.all else args.limit
    sys.exit(asyncio.run(run(args.model, limit, args.force, args.concurrency)))


if __name__ == "__main__":
    main()
