#!/usr/bin/env python3
"""Render the Gita brand: a vermillion ग on a yellow-to-orange ground.

Produces two working folders under `app/design/`, each with an editable SVG
master beside the rendered PNGs, and writes the app icon variants straight into
the AppIcon.appiconset:

    app/design/logo/     logo.svg, logo-1024.png, logo-dark.png, logo-tinted.png
    app/design/splash/   splash.svg, splash@1x/2x/3x.png

The SVGs are the editable masters — open them in Affinity Designer (or any
vector editor) and re-export, or change the constants here and rerun.

    .venv/bin/python tools/make_brand.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "app" / "design"
LOGO_DIR = DESIGN / "logo"
SPLASH_DIR = DESIGN / "splash"
ICONSET = ROOT / "app" / "Gita" / "Gita" / "Assets.xcassets" / "AppIcon.appiconset"

LETTER = "ग"
SIZE = 1024

# Vermillion — sindoor, the red of the tilak — against a marigold ground.
VERMILLION = (0xE0, 0x3C, 0x24)
VERMILLION_DARK = (0xFF, 0x6B, 0x4A)      # lifted, so it holds against a dark ground

GROUND_LIGHT = ((0xFF, 0xC7, 0x3B), (0xF0, 0x76, 0x18))   # yellow -> orange
GROUND_DARK = ((0x6B, 0x33, 0x08), (0x2A, 0x14, 0x06))    # the same ramp, banked down

# Devanagari faces, best first.
FONTS = [
    ("/System/Library/Fonts/Kohinoor.ttc", 2),
    ("/System/Library/Fonts/Supplemental/DevanagariMT.ttc", 1),
    ("/System/Library/Fonts/Supplemental/Devanagari Sangam MN.ttc", 1),
]

# Apple's icon grid keeps the subject inside roughly the middle 80%, so it
# survives the rounded-rect mask and the further crop the Home Screen applies.
LETTER_SCALE = 0.60


def font(size: int) -> ImageFont.FreeTypeFont:
    for path, index in FONTS:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    raise SystemExit("error: no Devanagari font found")


def gradient(start: tuple[int, int, int], end: tuple[int, int, int], size: int) -> Image.Image:
    """Top-left to bottom-right, built small and scaled for a smooth ramp."""
    small = Image.new("RGB", (2, 2))
    mid = tuple((s + e) // 2 for s, e in zip(start, end))
    small.putpixel((0, 0), start)
    small.putpixel((1, 0), mid)
    small.putpixel((0, 1), mid)
    small.putpixel((1, 1), end)
    return small.resize((size, size), Image.BICUBIC)


def glow(size: int) -> Image.Image:
    """A soft light from the upper left. Computed rather than drawn as rings —
    stacked ellipses band visibly on a large flat field."""
    resolution = 160
    small = Image.new("L", (resolution, resolution))
    cx, cy, radius = resolution * 0.32, resolution * 0.26, resolution * 0.78

    small.putdata([
        int(255 * max(0.0, 1.0 - (((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / radius)) ** 2)
        for y in range(resolution) for x in range(resolution)
    ])
    return small.resize((size, size), Image.BICUBIC)


def letter_mask(size: int) -> Image.Image:
    """The ग, centred on its drawn ink.

    Devanagari sits below a shirorekha (the headline) and glyph boxes carry
    space for matras above and below, so centring on the typographic box leaves
    the letter noticeably low. Measuring the drawn bounds is what centres it.
    """
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    face = font(int(size * LETTER_SCALE))

    left, top, right, bottom = draw.textbbox((0, 0), LETTER, font=face)
    x = (size - (right - left)) / 2 - left
    y = (size - (bottom - top)) / 2 - top
    draw.text((x, y), LETTER, font=face, fill=255)
    return mask


def compose(size: int, ground: tuple, ink: tuple, lit: bool = True) -> Image.Image:
    icon = gradient(*ground, size=size)

    if lit:
        highlight = Image.new("RGB", (size, size), (255, 255, 255))
        icon = Image.composite(highlight, icon, glow(size).point(lambda v: v // 4))

    mask = letter_mask(size)

    # A soft dark offset gives the letter weight without an obvious drop shadow.
    shadow = Image.new("RGB", (size, size), (0x6B, 0x24, 0x06))
    icon = Image.composite(shadow, icon, mask.point(lambda v: int(v * 0.30)))
    icon.paste(Image.new("RGB", (size, size), ink), (0, 0), mask)
    return icon


def tinted(size: int) -> Image.Image:
    """iOS applies its own colour to this one, so it must be greyscale with the
    subject light against a dark ground — any colour here is discarded."""
    icon = Image.new("RGB", (size, size), (0x1C, 0x1C, 0x1C))
    icon = Image.composite(Image.new("RGB", (size, size), (0x3E, 0x3E, 0x3E)), icon,
                           glow(size).point(lambda v: v // 2))
    icon.paste(Image.new("RGB", (size, size), (0xF4, 0xF4, 0xF4)), (0, 0), letter_mask(size))
    return icon


# --------------------------------------------------------------------- vectors


def svg(width: int, height: int, ground: tuple, ink: tuple, letter_fraction: float) -> str:
    """An editable master. Kept deliberately simple — two stops and one glyph —
    so it opens cleanly in a vector editor rather than as a mass of paths."""
    (r1, g1, b1), (r2, g2, b2) = ground
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}"
     viewBox="0 0 {width} {height}">
  <defs>
    <linearGradient id="ground" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#{r1:02X}{g1:02X}{b1:02X}"/>
      <stop offset="1" stop-color="#{r2:02X}{g2:02X}{b2:02X}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.32" cy="0.26" r="0.78">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.25"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="{width}" height="{height}" fill="url(#ground)"/>
  <rect width="{width}" height="{height}" fill="url(#glow)"/>

  <text x="{width / 2}" y="{height / 2}"
        font-family="Kohinoor Devanagari, Devanagari MT, sans-serif"
        font-size="{int(min(width, height) * letter_fraction)}"
        fill="#{ink[0]:02X}{ink[1]:02X}{ink[2]:02X}"
        text-anchor="middle" dominant-baseline="central">{LETTER}</text>
</svg>
'''


CONTENTS = {
    "images": [
        {"filename": "icon-light.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {
            "appearances": [{"appearance": "luminosity", "value": "dark"}],
            "filename": "icon-dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
        },
        {
            "appearances": [{"appearance": "luminosity", "value": "tinted"}],
            "filename": "icon-tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
        },
        {"filename": "icon-mac-512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
    ],
    "info": {"author": "xcode", "version": 1},
}


def main() -> None:
    for folder in (LOGO_DIR, SPLASH_DIR, ICONSET):
        folder.mkdir(parents=True, exist_ok=True)

    # --- logo -------------------------------------------------------------
    light = compose(SIZE, GROUND_LIGHT, VERMILLION)
    dark = compose(SIZE, GROUND_DARK, VERMILLION_DARK)
    grey = tinted(SIZE)

    light.save(LOGO_DIR / "logo-1024.png")
    dark.save(LOGO_DIR / "logo-dark.png")
    grey.save(LOGO_DIR / "logo-tinted.png")
    (LOGO_DIR / "logo.svg").write_text(svg(SIZE, SIZE, GROUND_LIGHT, VERMILLION, LETTER_SCALE))
    (LOGO_DIR / "logo-dark.svg").write_text(svg(SIZE, SIZE, GROUND_DARK, VERMILLION_DARK, LETTER_SCALE))

    # --- app icon ---------------------------------------------------------
    light.save(ICONSET / "icon-light.png")
    dark.save(ICONSET / "icon-dark.png")
    grey.save(ICONSET / "icon-tinted.png")
    light.resize((512, 512), Image.LANCZOS).save(ICONSET / "icon-mac-512.png")
    (ICONSET / "Contents.json").write_text(json.dumps(CONTENTS, indent=2) + "\n")

    # --- splash -----------------------------------------------------------
    # 1242x2688 is the tallest common portrait canvas; the mark sits small and
    # centred so it reads at any aspect the launch screen is cropped to.
    width, height = 1242, 2688
    for scale, name in ((1, "splash@1x.png"), (2, "splash@2x.png"), (3, "splash@3x.png")):
        canvas = Image.new("RGB", (width // 3 * scale, height // 3 * scale), (0xFF, 0xFF, 0xFF))
        mark_size = int(min(canvas.size) * 0.34)
        mark = compose(mark_size, GROUND_LIGHT, VERMILLION).resize((mark_size, mark_size), Image.LANCZOS)

        rounded = Image.new("L", (mark_size, mark_size), 0)
        ImageDraw.Draw(rounded).rounded_rectangle(
            [0, 0, mark_size - 1, mark_size - 1], radius=int(mark_size * 0.225), fill=255
        )
        canvas.paste(mark, ((canvas.width - mark_size) // 2, (canvas.height - mark_size) // 2), rounded)
        canvas.save(SPLASH_DIR / name)

    (SPLASH_DIR / "splash.svg").write_text(svg(width, height, GROUND_LIGHT, VERMILLION, 0.18))

    print(f"logo    -> {LOGO_DIR.relative_to(ROOT)}  (svg + 3 png)")
    print(f"splash  -> {SPLASH_DIR.relative_to(ROOT)}  (svg + 3 png)")
    print(f"icon    -> {ICONSET.relative_to(ROOT)}  (light, dark, tinted, mac)")


if __name__ == "__main__":
    main()
