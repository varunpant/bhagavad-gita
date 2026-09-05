#!/usr/bin/env python3
"""
Generate one social-share card per verse.

WhatsApp, Twitter/X, Telegram and Facebook all read og:image when a link is
pasted. The site previously served a single 1000x987 portrait PNG for all 700
pages, which those platforms crop badly and which says nothing about the page
being shared. This writes a 1200x630 card per verse showing the chapter, the
verse number, the Sanskrit line, a slice of the English translation, and the
site's own domain.

Output: themes/book/static/og/<chapter>-<sutra>.jpg  (+ og/default.jpg)
Run:    .venv/bin/python tools/make_og_images.py

Depends on macOS system fonts for Devanagari shaping (Pillow must be built
with Raqm; verify with PIL.features.check("raqm")).
"""

import csv
import os
import re
import sqlite3
import textwrap

from PIL import Image, ImageDraw, ImageFont, ImageOps, features

from build_db import normalize as normalize_shloka, strip_reference

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "themes", "book", "static", "og")
CSV_PATH = os.path.join(ROOT, "srimad.csv")
ENRICHED_DB = os.path.join(ROOT, "enriched.sqlite")
KRISHNA = os.path.join(ROOT, "themes", "book", "static", "krishna.png")

SITE = "bhagwadgita.info"
W, H = 1200, 630

# Palette mirrors --accent-* in themes/book/assets/css/main.css
GRAD_TOP = (255, 210, 74)
GRAD_BOT = (255, 122, 20)
INK = (74, 38, 0)
INK_SOFT = (120, 62, 8)

DEVA = "/System/Library/Fonts/Supplemental/Devanagari Sangam MN.ttc"
LATIN = "/System/Library/Fonts/Supplemental/Georgia.ttf"
LATIN_BOLD = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"

CHAPTERS = {
    1: ("अर्जुनविषादयोग", "The Despondency of Arjuna"),
    2: ("सांख्ययोग", "Transcendental Knowledge"),
    3: ("कर्मयोग", "The Path of Action"),
    4: ("ज्ञानकर्मसंन्यासयोग", "Knowledge and the Renunciation of Action"),
    5: ("कर्मसंन्यासयोग", "The Path of Renunciation"),
    6: ("आत्मसंयमयोग", "The Path of Meditation"),
    7: ("ज्ञानविज्ञानयोग", "Knowledge and Realisation"),
    8: ("अक्षरब्रह्मयोग", "The Imperishable Brahman"),
    9: ("राजविद्याराजगुह्ययोग", "The Royal Knowledge and Royal Secret"),
    10: ("विभूतियोग", "The Divine Manifestations"),
    11: ("विश्वरूपदर्शनयोग", "The Vision of the Cosmic Form"),
    12: ("भक्तियोग", "The Path of Devotion"),
    13: ("क्षेत्रक्षेत्रज्ञविभागयोग", "The Field and the Knower of the Field"),
    14: ("गुणत्रयविभागयोग", "The Three Gunas"),
    15: ("पुरुषोत्तमयोग", "The Supreme Person"),
    16: ("दैवासुरसम्पद्विभागयोग", "Divine and Demoniac Natures"),
    17: ("श्रद्धात्रयविभागयोग", "The Three Kinds of Faith"),
    18: ("मोक्षसंन्यासयोग", "Liberation through Renunciation"),
}


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient_bg():
    """Vertical yellow -> orange ramp, drawn once and reused for every card."""
    base = Image.new("RGB", (1, H))
    px = base.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(
            int(GRAD_TOP[i] + (GRAD_BOT[i] - GRAD_TOP[i]) * t) for i in range(3)
        )
    bg = base.resize((W, H), Image.BILINEAR)

    # Krishna as a line-art watermark on the right.
    #
    # krishna.png is gold line art on an opaque BLACK field with no alpha, so
    # neither its alpha channel nor an inverted mask works — both stamp a solid
    # rectangle. Luminance itself is the mask: black background -> 0 opacity,
    # the drawn figure -> paint.
    if os.path.exists(KRISHNA):
        art = Image.open(KRISHNA).convert("L")
        art.thumbnail((520, 520), Image.LANCZOS)
        mask = art.point(lambda v: int(v * 0.42))
        ink = Image.new("RGB", art.size, (255, 246, 214))
        bg.paste(ink, (W - art.width - 30, H - art.height - 15), mask)

    return bg


def clean(s):
    # The reference the scrape prefixes is stripped by the shared repair in
    # build_db, so a card cannot disagree with the page about where a sentence
    # starts. The `||` form is this script's own: some rows arrived with the
    # dandas transliterated.
    s = re.sub(r"^\|\|[\d.]+\|\|\s*", "", (s or ""))
    return re.sub(r"\s+", " ", strip_reference(s)).strip()


def enriched():
    """Every enriched verse, keyed by (chapter, sutra), or {} if absent.

    The card is a preview of the page, so it is drawn from what the page shows.
    Reading `srimad.csv` instead meant a card carried the scrape's own wording
    — visibly so on the 28 verses whose speaker attribution the page separates
    from the first word of what they say, which a card ran together.
    """
    if not os.path.exists(ENRICHED_DB):
        print("note: %s not found — drawing cards from the CSV" % ENRICHED_DB)
        return {}

    db = sqlite3.connect(ENRICHED_DB)
    db.row_factory = sqlite3.Row
    rows = {
        (int(r["chapter"]), int(r["sutra"])): r
        for r in db.execute(
            "SELECT chapter, sutra, sanskrit, english_translation FROM enriched_verses"
        )
    }
    db.close()
    return rows


def fit_lines(draw, text, fnt, max_width, max_lines):
    """Greedy wrap to pixel width, ellipsising when it runs past max_lines."""
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
            if len(lines) == max_lines:
                break
    if cur and len(lines) < max_lines:
        lines.append(cur)
    if len(lines) == max_lines and len(" ".join(lines)) < len(text) - 2:
        while lines[-1] and draw.textlength(lines[-1] + " …", font=fnt) > max_width:
            lines[-1] = lines[-1].rsplit(" ", 1)[0]
        lines[-1] += " …"
    return lines


def card(bg, chapter, sutra, shloka, english):
    img = bg.copy()
    d = ImageDraw.Draw(img)

    f_brand = font(DEVA, 44)
    f_ref = font(LATIN_BOLD, 92)
    f_ch_sa = font(DEVA, 40)
    f_ch_en = font(LATIN, 27)
    f_shloka = font(DEVA, 33)
    f_en = font(LATIN, 29)
    f_site = font(LATIN_BOLD, 31)

    pad = 72
    d.text((pad, 52), "श्रीमद् भगवद्गीता", font=f_brand, fill=INK)

    # Verse reference, the thing a reader actually recognises.
    d.text((pad, 118), "%s.%s" % (chapter, sutra), font=f_ref, fill=INK)

    sa, en = CHAPTERS.get(int(chapter), ("", ""))
    d.text((pad, 232), sa, font=f_ch_sa, fill=INK)
    d.text((pad, 284), "Chapter %s · %s" % (chapter, en), font=f_ch_en, fill=INK_SOFT)

    y = 344
    d.line([(pad, y), (pad + 120, y)], fill=INK, width=3)
    y += 26

    shloka = clean(shloka)
    if shloka:
        for line in fit_lines(d, shloka, f_shloka, 720, 2):
            d.text((pad, y), line, font=f_shloka, fill=INK)
            y += 44
        y += 6

    english = clean(english)
    if english:
        for line in fit_lines(d, english, f_en, 740, 2):
            d.text((pad, y), line, font=f_en, fill=INK_SOFT)
            y += 38

    # Footer sits on a fixed baseline so no card can run text into it.
    d.line([(pad, H - 96), (W - pad, H - 96)], fill=(255, 236, 190), width=2)
    d.text((pad, H - 76), SITE, font=f_site, fill=INK)
    return img


def main():
    if not features.check("raqm"):
        raise SystemExit(
            "Pillow lacks Raqm; Devanagari conjuncts would render incorrectly."
        )

    os.makedirs(OUT_DIR, exist_ok=True)
    bg = gradient_bg()

    # Fallback card for the homepage and anything without a verse.
    home = bg.copy()
    d = ImageDraw.Draw(home)
    d.text((72, 150), "श्रीमद् भगवद्गीता", font=font(DEVA, 86), fill=INK)
    d.text((72, 280), "Bhagavad Gita", font=font(LATIN_BOLD, 64), fill=INK)
    d.text((72, 368), "18 chapters · 700 verses · Sanskrit, Hindi & English",
           font=font(LATIN, 32), fill=INK_SOFT)
    d.text((72, H - 82), SITE, font=font(LATIN_BOLD, 31), fill=INK)
    home.save(os.path.join(OUT_DIR, "default.jpg"), "JPEG", quality=76, optimize=True, progressive=True)

    rows = enriched()
    count = 0
    with open(CSV_PATH) as f:
        for row in csv.DictReader(f):
            ch, su = row["chapter"], row["sutra"]
            # The database where it has the verse, the scrape where it does not.
            found = rows.get((int(ch), int(su)))
            shloka = normalize_shloka(found["sanskrit"]) if found else row.get("mool_shloka")
            english = found["english_translation"] if found else row.get("english_translation")
            img = card(bg, ch, su, shloka, english)
            img.save(
                os.path.join(OUT_DIR, "%s-%s.jpg" % (ch, su)),
                "JPEG", quality=76, optimize=True, progressive=True,
            )
            count += 1

    print("wrote %d cards to %s" % (count + 1, OUT_DIR))


if __name__ == "__main__":
    main()
