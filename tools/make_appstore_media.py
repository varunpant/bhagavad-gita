#!/usr/bin/env python3
"""Render the iPhone App Store media: five 6.9" panels and one preview video.

Nothing here is drawn by hand. The screens come out of the simulator, the share
card comes out of `ShareCard` itself, and this script only frames them:

    app/design/appstore/raw/          what the simulator and the renderer produced
    app/design/appstore/iphone-6.9/   the five 1290x2796 panels, ready to upload
    app/design/appstore/video/        preview.mp4, 886x1920

    .venv/bin/python tools/make_appstore_media.py

Stages, each skippable so a caption tweak does not mean a twelve-minute rerun:

    --skip-build     reuse the last test build
    --stills-only    capture and compose, no video
    --video-only     record the tour only
    --compose-only   just redraw the panels from what is already in raw/

The capture itself lives in `app/Gita/GitaUITests/ScreenshotUITests.swift` —
read that first if a panel is showing the wrong screen. The brand ramp is
imported from `make_brand.py` rather than repeated, so the panels can never
drift from the icon.

Two sizes worth knowing:

  * iPhone 16 Pro Max is 1320x2868, and App Store Connect accepts that as 6.9".
    The panels are composed at 1290x2796 anyway — the other accepted 6.9" size,
    and the one the rest of this repository's notes use — because the shot is
    inset in a frame, so it is scaled either way.
  * 1290x2796 and 886x1920 are the same 0.4614 aspect, so the recording
    downscales to the preview size with no crop and no letterbox.
"""

from __future__ import annotations

import argparse
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_brand import GROUND_LIGHT                                # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "app" / "Gita"
OUT = ROOT / "app" / "design" / "appstore"
RAW = OUT / "raw"
PANELS = OUT / "iphone-6.9"
VIDEO = OUT / "video"
# Outside the repository on purpose: a test build of this app is about a
# gigabyte, and the first version of this script put it under app/design/.
DERIVED = Path(tempfile.gettempdir()) / "gita-appstore-build"

# App Store Connect's 6.9" panel, and its preview video.
PANEL = (1290, 2796)
PREVIEW = (886, 1920)

# The 6.9" simulator to shoot on, newest runtime that has it.
DEVICE = "iPhone 16 Pro Max"

SERIF_BOLD = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SERIF = "/System/Library/Fonts/Supplemental/Georgia.ttf"

# One panel per captured screen. The caption is the whole marketing message —
# two short lines, because three is a paragraph and nobody reads a paragraph in
# a store carousel.
STILLS = [
    ("1-sanskrit", "All 700 verses,\nin the original Sanskrit"),
    ("2-english", "Every word rendered\nin English"),
    ("3-search", "Search the whole Gita\nin an instant"),
    ("4-progress", "See how far\nyou have come"),
]
CARD_PANEL = ("5-card", "Share any verse\nas a card")


# --------------------------------------------------------------------- helpers


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run a command, streaming nothing but keeping the output for diagnosis.

    Long silences are the failure mode this repository warns about, so every
    caller prints what it is about to do first.
    """
    return subprocess.run(command, capture_output=True, text=True, **kwargs)


def simulator() -> str:
    """The udid of the newest 6.9" iPhone runtime installed."""
    listing = run(["xcrun", "simctl", "list", "devices", "available"]).stdout
    found = re.findall(rf"^\s+{re.escape(DEVICE)} \(([0-9A-F-]+)\)", listing, re.M)
    if not found:
        raise SystemExit(f"error: no {DEVICE} simulator installed")
    return found[-1]          # simctl lists runtimes oldest first


def boot(udid: str) -> None:
    print(f"booting {DEVICE} ({udid[:8]})")
    run(["xcrun", "simctl", "boot", udid])
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=False)
    # 9:41, full bars, charged. Apple's own convention, and it keeps two runs
    # from differing only in the clock.
    run([
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "9:41",
        "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
        "--cellularMode", "active", "--cellularBars", "4",
        "--batteryState", "charged", "--batteryLevel", "100",
    ])


def xcodebuild(*arguments: str) -> None:
    command = ["xcodebuild", "-scheme", "Gita", "-derivedDataPath", str(DERIVED), *arguments]
    print("  " + " ".join(command[:6]) + " …")
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    if result.returncode != 0:
        tail = "\n".join(
            line for line in result.stdout.splitlines() if "error:" in line
        )[-4000:]
        raise SystemExit(f"error: xcodebuild failed\n{tail or result.stderr[-2000:]}")


# ------------------------------------------------------------------- capturing


def capture_stills(udid: str) -> None:
    """All four screens in one run.

    Which theme each one is shot in is decided in the test itself, with
    `-forceTheme` — the app stores its own theme preference, so
    `simctl ui appearance` has no say once one has been written.
    """
    print("capturing screens")
    xcodebuild("-destination", f"id={udid}", "test-without-building",
               *[f"-only-testing:GitaUITests/ScreenshotUITests/test{n}"
                 for n in ("1Sanskrit", "2English", "3Search", "4Progress")])


def capture_card() -> None:
    """The share card, rendered by the app's own `ShareCard` on macOS.

    Tapping through to it in the simulator lands on the system share sheet,
    which is Apple's UI and not worth a panel. `ShareCardSampleTests` writes the
    real card to the test process's temporary directory and prints where.
    """
    print("rendering the share card")
    command = [
        "xcodebuild", "-scheme", "Gita", "-derivedDataPath", str(DERIVED),
        "-destination", "platform=macOS",
        "-only-testing:GitaTests/ShareCardSampleTests", "test",
    ]
    result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True)
    written = re.findall(r"CARD_WRITTEN (\S+\.png)", result.stdout)
    english = [p for p in written if "english" in p]
    if not english:
        raise SystemExit("error: the share card was not rendered\n" + result.stdout[-2000:])
    shutil.copy(english[-1], RAW / "5-card.png")


def app_appears(movie: Path) -> float:
    """The second at which the app takes the screen.

    Recording starts before the test harness has installed and launched
    anything, so every take opens on some seconds of Home Screen — a variable
    number of them, since it depends on how long the launch took. Trimming a
    fixed offset would drift.

    The splash is the brand ramp, and a full screen of saturated saffron happens
    nowhere else in the app or on the Home Screen, so the first frame that is
    overwhelmingly warm is the first frame of the app. Falls back to the start
    of the recording rather than guessing, if nothing matches.
    """
    step = 0.2
    frames = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(movie),
         "-vf", f"fps={1 / step},scale=32:64", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True,
    ).stdout

    pixels = 32 * 64
    for index in range(len(frames) // (pixels * 3)):
        frame = frames[index * pixels * 3:(index + 1) * pixels * 3]
        red = sum(frame[0::3]) / pixels
        green = sum(frame[1::3]) / pixels
        blue = sum(frame[2::3]) / pixels
        if red > 200 and green > 110 and blue < 110:
            return index * step
    return 0.0


def record_video(udid: str) -> None:
    """Record the scripted tour, then transcode it to a preview.

    `simctl io recordVideo` writes until it is interrupted, so it runs alongside
    the tour test and takes a SIGINT when the test is done — killing it outright
    leaves an unfinalised, unplayable file.
    """
    VIDEO.mkdir(parents=True, exist_ok=True)
    source = VIDEO / "tour.mov"
    source.unlink(missing_ok=True)

    print("recording the tour")
    recorder = subprocess.Popen(
        ["xcrun", "simctl", "io", udid, "recordVideo", "--codec", "h264",
         "--force", str(source)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        xcodebuild("-destination", f"id={udid}",
                   "-only-testing:GitaUITests/ScreenshotUITests/test9Tour",
                   "test-without-building")
    finally:
        recorder.send_signal(signal.SIGINT)
        recorder.wait(timeout=60)

    start = app_appears(source)
    print(f"transcoding the preview, from {start:.1f}s")
    # A silent stereo track is deliberate: App Store Connect rejects previews
    # with no audio stream at all. 28s caps it under the 30s limit whatever the
    # simulator's pacing did.
    result = run([
        "ffmpeg", "-y", "-ss", f"{start:.2f}", "-i", str(source),
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-t", "28",
        "-vf", f"scale={PREVIEW[0]}:{PREVIEW[1]}:flags=lanczos,fps=30",
        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-b:v", "12M", "-c:a", "aac", "-b:a", "128k", "-shortest",
        "-movflags", "+faststart", str(VIDEO / "preview.mp4"),
    ])
    if result.returncode != 0:
        raise SystemExit("error: ffmpeg failed\n" + result.stderr[-2000:])


# -------------------------------------------------------------------- drawing


def ground(size: tuple[int, int]) -> Image.Image:
    """The brand ramp over the whole panel, from `make_brand.GROUND_LIGHT`."""
    small = Image.new("RGB", (1, len(GROUND_LIGHT)))
    for index, colour in enumerate(GROUND_LIGHT):
        small.putpixel((0, index), colour)
    return small.resize(size, Image.BICUBIC)


def rounded(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                           radius=radius, fill=255)
    return mask


def drop(panel: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    """A soft shadow under a rounded shape, blurred rather than stacked — the
    same reason `make_brand.glow` is computed: stacked outlines band."""
    left, top, width, height = box
    shadow = Image.new("L", panel.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, top + 26, left + width, top + height + 26], radius=radius, fill=150
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(46))
    panel.paste(Image.new("RGB", panel.size, (0x6B, 0x22, 0x06)), (0, 0), shadow)


def caption(panel: Image.Image, text: str) -> int:
    """Two centred lines at the top. Returns the y the artwork may start at."""
    draw = ImageDraw.Draw(panel)
    face = ImageFont.truetype(SERIF_BOLD, 88)
    top = 186

    # Deep brown, not white. The panel's caption sits on the yellow end of the
    # ramp, which is the one place white loses its contrast — at carousel size
    # it goes soft and unreadable. The pale line under it is a lift, not a
    # shadow: it separates the letters from the ground without a halo.
    for offset, fill in (((0, 3), (0xFF, 0xE7, 0xA8)), ((0, 0), (0x63, 0x22, 0x06))):
        draw.multiline_text(
            (panel.width // 2 + offset[0], top + offset[1]), text, font=face,
            fill=fill, anchor="ma", align="center", spacing=26,
        )

    _, _, _, bottom = draw.multiline_textbbox((panel.width // 2, top), text,
                                              font=face, anchor="ma", spacing=26)
    return int(bottom)


def device_panel(shot: Image.Image, text: str) -> Image.Image:
    """A screenshot in a phone, running off the bottom edge of the panel."""
    panel = ground(PANEL)
    top = caption(panel, text) + 96

    width = int(PANEL[0] * 0.72)
    height = int(width * shot.height / shot.width)
    bezel, radius = 16, int(width * 0.105)

    left = (PANEL[0] - width) // 2
    drop(panel, (left, top, width, height), radius)

    body = Image.new("RGB", (width, height), (0x1A, 0x14, 0x12))
    inner = shot.resize((width - bezel * 2, height - bezel * 2), Image.LANCZOS)
    body.paste(inner, (bezel, bezel), rounded(inner.size, radius - bezel))
    panel.paste(body, (left, top), rounded(body.size, radius))
    return panel


def card_panel(card: Image.Image, text: str) -> Image.Image:
    """The share card is square and is its own artwork — no phone around it."""
    panel = ground(PANEL)
    top = caption(panel, text)

    side = int(PANEL[0] * 0.80)
    radius = int(side * 0.06)
    left = (PANEL[0] - side) // 2
    top += (PANEL[1] - top - side) // 2          # centred in what is left

    drop(panel, (left, top, side, side), radius)
    square = card.resize((side, side), Image.LANCZOS)
    panel.paste(square, (left, top), rounded(square.size, radius))
    return panel


def compose() -> None:
    PANELS.mkdir(parents=True, exist_ok=True)
    for name, text in STILLS:
        source = RAW / f"{name}.png"
        if not source.exists():
            raise SystemExit(f"error: {source.relative_to(ROOT)} is missing — capture first")
        device_panel(Image.open(source).convert("RGB"), text).save(PANELS / f"{name}.png")
        print(f"  {name}")

    name, text = CARD_PANEL
    source = RAW / "5-card.png"
    if source.exists():
        card_panel(Image.open(source).convert("RGB"), text).save(PANELS / f"{name}.png")
        print(f"  {name}")


# ------------------------------------------------------------------------ main


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--stills-only", action="store_true")
    parser.add_argument("--video-only", action="store_true")
    parser.add_argument("--compose-only", action="store_true")
    options = parser.parse_args()

    RAW.mkdir(parents=True, exist_ok=True)

    if options.compose_only:
        return compose()

    udid = simulator()
    boot(udid)

    if not options.skip_build:
        print("building for testing")
        xcodebuild("-destination", f"id={udid}", "build-for-testing")

    if not options.video_only:
        capture_stills(udid)
        capture_card()
        print("composing panels")
        compose()

    if not options.stills_only:
        record_video(udid)

    print(f"\npanels -> {PANELS.relative_to(ROOT)}")
    print(f"video  -> {(VIDEO / 'preview.mp4').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
