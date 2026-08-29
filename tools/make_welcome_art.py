#!/usr/bin/env python3
"""Pack the welcome slider's screenshots into the app's asset catalogue.

The shots are taken by `GitaUITests/WelcomeArtUITests`, which drives the real
app to each screen the welcome talks about, in both scripts, and writes them to
`app/design/media/welcome/<script>/`. This trims the status bar off each one,
scales it to the width the card draws at, and writes an imageset per picture:

    xcodebuild … -only-testing:GitaUITests/WelcomeArtUITests test
    .venv/bin/python tools/make_welcome_art.py

They are committed, like `gita.sqlite` and the social cards, and they go stale
the same way: **reshoot them after changing any screen the welcome shows.**

Why screenshots rather than the live views they replaced: a live miniature is
always current but is not what the reader will see — it has no status bar, no
rail, none of the app's real proportions. A screenshot is the app.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "app" / "design" / "media" / "welcome"
ASSETS = ROOT / "app" / "Gita" / "Gita" / "Assets.xcassets"

# The card is 560pt wide at its largest, drawn @3x — 1680px is the most any
# screen can ask for, and the phone's 320pt card downscales from the same file.
TARGET_WIDTH = 1680

# The status bar is the simulator's, not the app's: 9:41 and a full battery
# inside a welcome card is furniture from another screen. iPhone 16 Pro Max is
# 2868 tall, and the bar ends about 4% down.
TRIM_TOP = 0.045

# The rail is 72pt wide, which is 216px on the 3x captures.
RAIL = 216

# Shots that keep the rail, and shots that lose it.
#
# A panel opened from the rail is always drawn beside it, so four of the six
# screenshots carried the same saffron strip down their left edge — the slider
# looked like six photographs of one thing. The contents keeps it, because that
# is the page that says where the panels live; the others are cropped to the
# panel itself.
CROP_RAIL = {"appearance", "progress"}


def imageset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)

    image.save(folder / f"{name}.png", optimize=True)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }, indent=2) + "\n")


def main() -> None:
    if not SHOTS.exists():
        raise SystemExit(f"error: no shots in {SHOTS.relative_to(ROOT)} — run the capture first")

    packed = 0
    for script in ("en", "sa"):
        for shot in sorted((SHOTS / script).glob("*.png")):
            image = Image.open(shot).convert("RGB")
            top = int(image.height * TRIM_TOP)
            left = RAIL if shot.stem in CROP_RAIL else 0
            image = image.crop((left, top, image.width, image.height))

            scale = TARGET_WIDTH / image.width
            image = image.resize(
                (TARGET_WIDTH, int(image.height * scale)), Image.LANCZOS
            )
            imageset(f"welcome-{shot.stem}-{script}", image)
            packed += 1

    print(f"packed {packed} imagesets into {ASSETS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
