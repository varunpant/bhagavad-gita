"""Favicon and touch icons, cut from the app's own icon.

The site and the app are one product, so the tab should carry the mark the app
carries — the white ग on the saffron ramp — rather than the unrelated 16px .ico
that has been there since 2024.

It is not a straight resize. The app icon leaves a wide margin around the glyph
because iOS rounds the corners off and puts it on a home screen among others; a
favicon is 16 pixels on a crowded tab strip, and at that size the same margin
leaves the ग about six pixels tall and unreadable. So the glyph is measured and
the tile is cropped to a fixed share of it, which enlarges the mark without
redrawing it. The ramp is a smooth vertical gradient, so cropping into it costs
nothing.

    ../.venv/bin/python tools/make_favicon.py

Writes into themes/book/static/, which Hugo copies to docs/ verbatim.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "app/Gita/Gita/Assets.xcassets/AppIcon.appiconset/icon-light.png"
STATIC = ROOT / "themes/book/static"

# How much of the finished tile the glyph should span. The app icon sits at
# about 0.38; 0.62 is what makes it legible at 16 pixels without the arms of
# the ग touching the edge.
GLYPH_SHARE = 0.62

ICO_SIZES = [16, 32, 48, 64]
TOUCH_SIZE = 180


def glyph_box(image: Image.Image) -> tuple[int, int, int, int]:
    """The bounding box of the white mark on the ramp.

    Found by threshold rather than by alpha: the icon is opaque, so the glyph
    is simply the near-white pixels.
    """
    grey = image.convert("L")
    mask = grey.point(lambda value: 255 if value > 230 else 0)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("error: found no glyph in the icon — has the art changed?")
    return box


def cropped(image: Image.Image) -> Image.Image:
    left, top, right, bottom = glyph_box(image)
    glyph = max(right - left, bottom - top)
    side = int(round(glyph / GLYPH_SHARE))

    # Centre the crop on the glyph, then pull it back inside the tile rather
    # than letting it run off an edge and lose part of the mark.
    centre_x, centre_y = (left + right) // 2, (top + bottom) // 2
    side = min(side, image.width, image.height)
    x = min(max(centre_x - side // 2, 0), image.width - side)
    y = min(max(centre_y - side // 2, 0), image.height - side)
    return image.crop((x, y, x + side, y + side))


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"error: {SOURCE} not found")

    icon = cropped(Image.open(SOURCE).convert("RGB"))

    ico = STATIC / "favicon.ico"
    icon.save(ico, sizes=[(size, size) for size in ICO_SIZES])
    print(f"wrote {ico.relative_to(ROOT)} ({', '.join(str(s) for s in ICO_SIZES)})")

    for name, size in (("apple-touch-icon.png", TOUCH_SIZE), ("icon-512.png", 512)):
        path = STATIC / name
        icon.resize((size, size), Image.LANCZOS).save(path, optimize=True)
        print(f"wrote {path.relative_to(ROOT)} ({size}px)")


if __name__ == "__main__":
    main()
