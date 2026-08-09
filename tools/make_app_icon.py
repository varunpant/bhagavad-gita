#!/usr/bin/env python3
"""Render the Gita app icon: a gold g on an orange gradient.

Writes the three 1024×1024 variants iOS asks for — light, dark and tinted —
straight into the app's AppIcon.appiconset, plus a standalone logo for anything
outside the app (README, store listing, the website).

Committed as source rather than as a one-off export: the icon can be adjusted by
changing a colour here and rerunning, and the tinted variant in particular has
rules that are easy to get wrong by hand.

    .venv/bin/python tools/make_app_icon.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "app" / "Gita" / "Gita" / "Assets.xcassets" / "AppIcon.appiconset"
LOGO = ROOT / "app" / "design" / "logo-1024.png"

SIZE = 1024
LETTER = "g"
# Lowercase carries a descender, so the same point size draws a visibly smaller
# letter than a capital would. Sized up to match the optical weight, and the
# bounding-box centring below then places it correctly despite the tail.
LETTER_SCALE = 0.82

# Saffron, matching the app's accent tokens (specs.md §9.1) rather than an
# unrelated orange, so the icon and the interface agree.
LIGHT = ((0xF2, 0xA0, 0x3D), (0xC8, 0x61, 0x1C))
DARK = ((0xC8, 0x61, 0x1C), (0x6B, 0x2F, 0x0B))

# Gold for the letter: a highlight at the top, deeper at the foot, so the G
# reads as metal rather than as flat yellow.
GOLD = ((0xFF, 0xE9, 0xA8), (0xF0, 0xC3, 0x55), (0xB8, 0x82, 0x22))

# Serif, for a letter that belongs on a book rather than in an interface.
FONTS = [
    "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf",
    "/Library/Fonts/Georgia Bold.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONTS:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise SystemExit(f"error: none of these fonts exist:\n  " + "\n  ".join(FONTS))


def diagonal_gradient(start: tuple[int, int, int], end: tuple[int, int, int]) -> Image.Image:
    """Corner-to-corner gradient.

    Built tiny and scaled up: interpolating 4 pixels to 1024 is both smoother
    and far faster than looping over a million of them in Python.
    """
    small = Image.new("RGB", (2, 2))
    mid = tuple((s + e) // 2 for s, e in zip(start, end))
    small.putpixel((0, 0), start)
    small.putpixel((1, 0), mid)
    small.putpixel((0, 1), mid)
    small.putpixel((1, 1), end)
    return small.resize((SIZE, SIZE), Image.BICUBIC)


def vertical_gradient(stops: tuple[tuple[int, int, int], ...]) -> Image.Image:
    small = Image.new("RGB", (1, len(stops)))
    for index, colour in enumerate(stops):
        small.putpixel((0, index), colour)
    return small.resize((SIZE, SIZE), Image.BICUBIC)


def glow() -> Image.Image:
    """A soft light from the upper left, so the ground is not a flat ramp.

    Computed as a smooth radial falloff rather than drawn as concentric
    ellipses: stacked ellipses scaled up 8x band visibly, which on a large flat
    field of orange reads as a smudge rather than as light.
    """
    resolution = 128
    small = Image.new("L", (resolution, resolution))
    centre_x, centre_y = resolution * 0.34, resolution * 0.30
    radius = resolution * 0.72

    pixels = []
    for y in range(resolution):
        for x in range(resolution):
            distance = ((x - centre_x) ** 2 + (y - centre_y) ** 2) ** 0.5 / radius
            falloff = max(0.0, 1.0 - distance) ** 2      # smooth to zero at the edge
            pixels.append(int(255 * falloff))
    small.putdata(pixels)
    return small.resize((SIZE, SIZE), Image.BICUBIC)


def letter_mask() -> Image.Image:
    """The letter, centred on its own ink rather than on its typographic box.

    A glyph's advance width and line height include side bearings and space for
    descenders, so centring by those leaves the letter visibly high and to the
    left. Measuring the drawn bounding box and centring that is what actually
    looks centred.
    """
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)
    face = font(int(SIZE * LETTER_SCALE))

    left, top, right, bottom = draw.textbbox((0, 0), LETTER, font=face)
    x = (SIZE - (right - left)) / 2 - left
    y = (SIZE - (bottom - top)) / 2 - top
    draw.text((x, y), LETTER, font=face, fill=255)
    return mask


def compose(background: Image.Image) -> Image.Image:
    icon = background.copy()

    highlight = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    icon = Image.composite(highlight, icon, glow().point(lambda v: v // 3))

    gold = vertical_gradient(GOLD)
    mask = letter_mask()

    # A soft dark offset under the letter gives it weight against the orange.
    shadow = Image.new("RGB", (SIZE, SIZE), (0x5A, 0x28, 0x08))
    icon = Image.composite(shadow, icon, mask.point(lambda v: int(v * 0.35)))
    icon.paste(gold, (0, 0), mask)
    return icon


def tinted() -> Image.Image:
    """iOS tints this variant itself, so it must be greyscale with the subject
    light against a dark ground — colour here would be discarded or muddied."""
    icon = Image.new("RGB", (SIZE, SIZE), (0x1C, 0x1C, 0x1C))
    icon = Image.composite(Image.new("RGB", (SIZE, SIZE), (0x3A, 0x3A, 0x3A)), icon,
                           glow().point(lambda v: v // 2))
    icon.paste(Image.new("RGB", (SIZE, SIZE), (0xF2, 0xF2, 0xF2)), (0, 0), letter_mask())
    return icon


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
    ICONSET.mkdir(parents=True, exist_ok=True)
    LOGO.parent.mkdir(parents=True, exist_ok=True)

    light = compose(diagonal_gradient(*LIGHT))
    light.save(ICONSET / "icon-light.png")
    compose(diagonal_gradient(*DARK)).save(ICONSET / "icon-dark.png")
    tinted().save(ICONSET / "icon-tinted.png")
    light.resize((512, 512), Image.LANCZOS).save(ICONSET / "icon-mac-512.png")
    light.save(LOGO)

    (ICONSET / "Contents.json").write_text(json.dumps(CONTENTS, indent=2) + "\n")

    print(f"wrote 4 icon files to {ICONSET.relative_to(ROOT)}")
    print(f"wrote {LOGO.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
