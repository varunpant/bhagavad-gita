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
from make_brand import GROUND_LIGHT, compose as brand_mark         # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "app" / "Gita"
OUT = ROOT / "app" / "design" / "appstore"
RAW = OUT / "raw"
PANELS = OUT / "iphone-6.9"
PANELS_65 = OUT / "iphone-6.5"
PANELS_IPAD = OUT / "ipad-13"
VIDEO = OUT / "video"
# Outside the repository on purpose: a test build of this app is about a
# gigabyte, and the first version of this script put it under app/design/.
DERIVED = Path(tempfile.gettempdir()) / "gita-appstore-build"

# App Store Connect's 6.9" panel, and its preview video.
PANEL = (1290, 2796)
# The 6.5" set, for the row that predates it. Providing 6.9" is enough on its
# own — Connect scales it down for every smaller iPhone — but the 6.5" row is
# still on the page and refuses a 6.9" file, which reads as "the dimensions are
# wrong" rather than as "that is the wrong row". Composing both makes the
# question moot.
PANEL_65 = (1284, 2778)
# The 13" iPad panel. Required as soon as iPad stays in the app record, and the
# iPad Pro 13-inch (M4) simulator is exactly this many pixels in portrait, so
# the shot is placed rather than scaled.
PANEL_IPAD = (2064, 2752)
PREVIEW = (886, 1920)
# The iPad app preview. Same 0.75 aspect as the 13" simulator's portrait screen,
# so the recording downscales with no crop and no letterbox — the same luck the
# iPhone pair has.
PREVIEW_IPAD = (1200, 1600)

# The simulators to shoot on, newest runtime that has each.
DEVICE = "iPhone 16 Pro Max"
DEVICE_IPAD = "iPad Pro 13-inch (M4)"

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

# The preview's captions, one per beat of the tour, keyed by the name the tour
# records in `tour-timeline.json`. The copy lives here rather than in the test so
# it can be rewritten without rebuilding a test target — the test decides *when*
# a beat happens, this decides what it says. Two lines, same as the panels.
CAPTIONS = {
    "opening": "All 700 verses,\nin the original Sanskrit",
    "verse": "Translation, meaning,\nand every word explained",
    "language": "Read in Sanskrit\nor in English",
    "contents": "Every chapter, every verse —\nthe famous ones ringed in gold",
    "search": "Search by word, meaning\nor number — instantly, offline",
    "keep": "Keep a verse,\nor share it as a card",
    "progress": "Read at your own pace —\nthirty-five goals on the way",
}

# The closing card: the mark, the name, and the one line nothing else in the
# video says. Held long enough to survive being the poster frame and being what
# is on screen when the loop comes round again.
CARD_SECONDS = 2.4
CARD_LINES = ("No account. No ads. No tracking.", "Works offline.")

# App Store Connect takes 15-30s. The tour is paced for about 24s of app; this
# is the ceiling it is squeezed into if the simulator ran slow on the day.
FOOTAGE_MAX = 27.4
# Beyond this the squeeze is visible as hurry rather than as pace.
FASTEST = 1.25

# The caption band: clear of the frame's edges, and roomy around its own text.
CAPTION_MARGIN, CAPTION_PADDING = 40, 30


# --------------------------------------------------------------------- helpers


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run a command, streaming nothing but keeping the output for diagnosis.

    Long silences are the failure mode this repository warns about, so every
    caller prints what it is about to do first.
    """
    return subprocess.run(command, capture_output=True, text=True, **kwargs)


def simulator(device: str = DEVICE) -> str:
    """The udid of the newest runtime installed for a named simulator."""
    listing = run(["xcrun", "simctl", "list", "devices", "available"]).stdout
    found = re.findall(rf"^\s+{re.escape(device)} \(([0-9A-F-]+)\)", listing, re.M)
    if not found:
        raise SystemExit(f"error: no {device} simulator installed")
    return found[-1]          # simctl lists runtimes oldest first


def boot(udid: str, device: str = DEVICE) -> None:
    print(f"booting {device} ({udid[:8]})")
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
    """Record the scripted tour, then build the preview from it.

    `simctl io recordVideo` writes until it is interrupted, so it runs alongside
    the tour test and takes a SIGINT when the test is done — killing it outright
    leaves an unfinalised, unplayable file.
    """
    VIDEO.mkdir(parents=True, exist_ok=True)
    source = VIDEO / "tour.mov"
    source.unlink(missing_ok=True)
    (RAW / "tour-timeline.json").unlink(missing_ok=True)

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

    build_preview()


def timeline() -> list[tuple[str, float, float]]:
    """The tour's beats as (name, start, end), in seconds from the app appearing.

    Written by the tour itself, because the sleeps in it are not the timings:
    every tap costs an animation and every query costs a layout pass, and by the
    last beat a guess made from the source is seconds out. The run measures
    itself and leaves the answer beside the recording.
    """
    written = RAW / "tour-timeline.json"
    if not written.exists():
        raise SystemExit(f"error: {written.relative_to(ROOT)} is missing — record first")

    import json
    entries = json.loads(written.read_text())
    beats = [(entry["name"], float(entry["at"]), float(entry.get("show", entry["at"])))
             for entry in entries]
    if len(beats) < 2 or beats[-1][0] != "end":
        raise SystemExit("error: the tour timeline is incomplete — the run did not finish")

    # A caption runs from its beat's payoff to the start of the next beat: the
    # taps that set a screen up are not what the caption is talking about.
    return [(name, show, beats[index + 1][1])
            for index, (name, _, show) in enumerate(beats[:-1])]


def build_preview() -> None:
    """Trim, scale, caption, and hang the closing card off the end.

    Split from the recording on purpose: rewriting a caption is a fifteen-second
    job against the take already on disk, and re-shooting for it would be four
    minutes of simulator per word.
    """
    source = VIDEO / "tour.mov"
    if not source.exists():
        raise SystemExit(f"error: {source.relative_to(ROOT)} is missing — record first")

    beats = timeline()
    start = app_appears(source)
    footage = beats[-1][2]

    # If the simulator ran slow, take the whole thing slightly faster rather
    # than cutting the last beat off. A tenth quicker reads as pace; a missing
    # progress screen reads as a shorter app.
    rate = max(1.0, footage / FOOTAGE_MAX)
    if rate > FASTEST:
        raise SystemExit(
            f"error: the tour ran {footage:.1f}s, which needs a {rate:.2f}x squeeze "
            f"to fit {FOOTAGE_MAX:.0f}s. Shorten the holds in test9Tour instead."
        )
    if rate > 1.0:
        print(f"  the tour ran {footage:.1f}s — taking it {rate:.2f}x faster")

    card = closing_card()
    print(f"transcoding the preview, from {start:.1f}s "
          f"({footage / rate:.1f}s + {CARD_SECONDS:.1f}s card)")

    with tempfile.TemporaryDirectory() as scratch:
        bands: list[tuple[Path, float, float]] = []
        # Padded in at both ends, so a caption never straddles a transition.
        pad = 0.2
        for index, (name, opens, closes) in enumerate(beats):
            text = CAPTIONS.get(name)
            if text is None:
                continue
            band = caption_band(text, Path(scratch) / f"{index}.png")
            bands.append((band, opens / rate + pad,
                          max(closes / rate - pad, opens / rate + pad + 0.5)))

        length = footage / rate
        inputs = [
            "-ss", f"{start:.2f}", "-t", f"{footage:.2f}", "-i", str(source),
            "-loop", "1", "-t", f"{CARD_SECONDS}", "-i", str(card),
        ]
        for band, _, _ in bands:
            inputs += ["-loop", "1", "-t", f"{length:.2f}", "-i", str(band)]
        inputs += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100"]

        steps = [
            f"[0:v]scale={PREVIEW[0]}:{PREVIEW[1]}:flags=lanczos,"
            f"setpts=PTS/{rate:.4f},fps=30,setsar=1[tour0]"
        ]
        for index, (_, opens, closes) in enumerate(bands):
            # The band sits clear of the home indicator, and clear of the top
            # third, where the verse reference and the rail live.
            steps.append(
                f"[tour{index}][{index + 2}:v]"
                f"overlay=x=(W-w)/2:y=H-h-150:"
                f"enable=between(t\\,{opens:.2f}\\,{closes:.2f})[tour{index + 1}]"
            )
        steps.append(f"[tour{len(bands)}]format=yuv420p[tour]")
        steps.append(
            f"[1:v]scale={PREVIEW[0]}:{PREVIEW[1]},fps=30,setsar=1,format=yuv420p[card]"
        )
        steps.append("[tour][card]concat=n=2:v=1:a=0[v]")

        # A silent stereo track is deliberate: App Store Connect rejects
        # previews with no audio stream at all.
        result = run([
            "ffmpeg", "-y", *inputs,
            "-filter_complex", ";".join(steps),
            "-map", "[v]", "-map", f"{len(bands) + 2}:a",
            "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
            "-b:v", "12M", "-c:a", "aac", "-b:a", "128k", "-shortest",
            "-movflags", "+faststart", str(VIDEO / "preview.mp4"),
        ])
    if result.returncode != 0:
        raise SystemExit("error: ffmpeg failed\n" + result.stderr[-2000:])


def caption_face(frame: tuple[int, int] = PREVIEW) -> ImageFont.FreeTypeFont:
    """The one size every caption is set in.

    Fitted to the longest line in `CAPTIONS` rather than to each caption
    separately: sized one at a time, a short line came out half again as big as
    a long one, and captions that change size between beats read as seven
    different designs rather than one.
    """
    k = frame[0] / PREVIEW[0]
    room = frame[0] - (CAPTION_MARGIN + CAPTION_PADDING) * 2 * k
    lines = [line for text in CAPTIONS.values() for line in text.split("\n")]
    for points in range(int(50 * k), int(29 * k), -2):
        face = ImageFont.truetype(SERIF_BOLD, points)
        if max(face.getbbox(line)[2] for line in lines) <= room:
            return face
    return ImageFont.truetype(SERIF_BOLD, int(30 * k))


def caption_band(text: str, into: Path,
                 frame: tuple[int, int] = PREVIEW) -> Path:
    """One caption, drawn as a band and saved as a transparent PNG.

    Drawn with Pillow rather than with ffmpeg's `drawtext`, for two reasons. The
    ffmpeg on this machine is built without freetype, so `drawtext` does not
    exist in it at all — and even where it does, this way the video's captions
    and the panels' captions come out of the same renderer, in the same face, on
    the same ground. One place to change how a caption looks.

    A band rather than bare letters on the page: over a paragraph of Devanagari,
    text alone half-disappears into the strokes behind it. Deep brown on the pale
    ground, the same pairing as the panels — white on the yellow end of the brand
    ramp is the one place it loses its contrast.
    """
    k = frame[0] / PREVIEW[0]
    padding, spacing = int(CAPTION_PADDING * k), int(14 * k)
    face = caption_face(frame)

    measure = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    _, top, _, bottom = measure.multiline_textbbox((0, 0), text, font=face,
                                                   spacing=spacing)
    height = int(bottom - top) + padding * 2

    band = Image.new("RGBA", (frame[0] - int(CAPTION_MARGIN * 2 * k), height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(band)
    draw.rounded_rectangle([0, 0, band.width - 1, band.height - 1], radius=int(26 * k),
                           fill=(0xFF, 0xE7, 0xA8, 235))
    draw.multiline_text((band.width // 2, padding - top), text, font=face,
                        fill=(0x63, 0x22, 0x06, 255), anchor="ma",
                        align="center", spacing=spacing)
    band.save(into)
    return into


def closing_card(frame: tuple[int, int] = PREVIEW, name: str = "closing") -> Path:
    """The last frame: the mark on the brand ground, the name, the promise."""
    k = frame[0] / PREVIEW[0]
    card = ground(frame)
    side = int(360 * k)
    mark = brand_mark(side, GROUND_LIGHT)

    top = int(frame[1] * 0.30)
    left = (frame[0] - side) // 2
    drop(card, (left, top, side, side), int(80 * k))
    card.paste(mark, (left, top), rounded(mark.size, int(80 * k)))

    draw = ImageDraw.Draw(card)
    y = top + side + int(90 * k)
    for text, points, colour, gap in (
        ("Gita", 92, (0x63, 0x22, 0x06), 124),
        (CARD_LINES[0], 40, (0x7A, 0x2E, 0x08), 56),
        (CARD_LINES[1], 40, (0x7A, 0x2E, 0x08), 0),
    ):
        face = ImageFont.truetype(SERIF_BOLD if points == 92 else SERIF, int(points * k))
        draw.text((frame[0] // 2, y + int(3 * k)), text, font=face,
                  fill=(0xFF, 0xE7, 0xA8), anchor="ma")
        draw.text((frame[0] // 2, y), text, font=face, fill=colour, anchor="ma")
        y += int(gap * k)

    path = VIDEO / f"{name}.png"
    card.save(path)
    return path


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


def scale(panel: Image.Image) -> float:
    """How much bigger this panel is than the 6.9" one everything was drawn for.

    The type size, the offsets, the bezel and the blur radius were all chosen
    against a 1290-wide panel. On a 2064-wide iPad panel the same pixel values
    are two thirds the size — a caption that looked like a headline becomes a
    label. Every one of them is multiplied through this instead.
    """
    return panel.width / PANEL[0]


def drop(panel: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    """A soft shadow under a rounded shape, blurred rather than stacked — the
    same reason `make_brand.glow` is computed: stacked outlines band."""
    left, top, width, height = box
    k = scale(panel)
    shadow = Image.new("L", panel.size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, top + 26 * k, left + width, top + height + 26 * k],
        radius=radius, fill=150,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(46 * k))
    panel.paste(Image.new("RGB", panel.size, (0x6B, 0x22, 0x06)), (0, 0), shadow)


def caption(panel: Image.Image, text: str) -> int:
    """Two centred lines at the top. Returns the y the artwork may start at."""
    k = scale(panel)
    draw = ImageDraw.Draw(panel)
    face = ImageFont.truetype(SERIF_BOLD, int(88 * k))
    top = int(186 * k)
    spacing = int(26 * k)

    # Deep brown, not white. The panel's caption sits on the yellow end of the
    # ramp, which is the one place white loses its contrast — at carousel size
    # it goes soft and unreadable. The pale line under it is a lift, not a
    # shadow: it separates the letters from the ground without a halo.
    for offset, fill in (((0, int(3 * k)), (0xFF, 0xE7, 0xA8)),
                         ((0, 0), (0x63, 0x22, 0x06))):
        draw.multiline_text(
            (panel.width // 2 + offset[0], top + offset[1]), text, font=face,
            fill=fill, anchor="ma", align="center", spacing=spacing,
        )

    _, _, _, bottom = draw.multiline_textbbox((panel.width // 2, top), text,
                                              font=face, anchor="ma", spacing=spacing)
    return int(bottom)


def device_panel(shot: Image.Image, text: str, size: tuple[int, int] = PANEL,
                 across: float = 0.72, corner: float = 0.105) -> Image.Image:
    """A screenshot in a device, running off the bottom edge of the panel.

    `across` and `corner` are what make the same drawing work for a tablet: an
    iPad is wider in proportion and its corners are far less round, and a 13"
    shot in a phone-shaped frame with phone-sized corners reads as a phone
    someone stretched.
    """
    panel = ground(size)
    k = scale(panel)
    top = caption(panel, text) + int(96 * k)

    width = int(size[0] * across)
    height = int(width * shot.height / shot.width)
    bezel, radius = int(16 * k), int(width * corner)

    left = (size[0] - width) // 2
    drop(panel, (left, top, width, height), radius)

    body = Image.new("RGB", (width, height), (0x1A, 0x14, 0x12))
    inner = shot.resize((width - bezel * 2, height - bezel * 2), Image.LANCZOS)
    body.paste(inner, (bezel, bezel), rounded(inner.size, radius - bezel))
    panel.paste(body, (left, top), rounded(body.size, radius))
    return panel


def card_panel(card: Image.Image, text: str,
               size: tuple[int, int] = PANEL) -> Image.Image:
    """The share card is square and is its own artwork — no phone around it."""
    panel = ground(size)
    top = caption(panel, text)

    side = int(size[0] * 0.80)
    radius = int(side * 0.06)
    left = (size[0] - side) // 2
    top += (size[1] - top - side) // 2           # centred in what is left

    drop(panel, (left, top, side, side), radius)
    square = card.resize((side, side), Image.LANCZOS)
    panel.paste(square, (left, top), rounded(square.size, radius))
    return panel


def compose_ipad() -> None:
    """The 13" iPad panels, from the iPad captures.

    Kept apart from the iPhone sets because the shots are different files: an
    iPad screen is not an iPhone screen scaled, and the panel has to show the
    app as it lays itself out on a tablet or the panel is a lie.
    """
    shots = RAW / "ipad"
    if not (shots / "1-sanskrit.png").exists():
        raise SystemExit("error: no iPad captures — run with --ipad first")

    PANELS_IPAD.mkdir(parents=True, exist_ok=True)
    print(f"  {PANELS_IPAD.name}")
    for name, text in STILLS:
        source = shots / f"{name}.png"
        if not source.exists():
            raise SystemExit(f"error: {source.relative_to(ROOT)} is missing")
        panel = device_panel(Image.open(source).convert("RGB"), text, PANEL_IPAD,
                             across=0.78, corner=0.038)
        panel.save(PANELS_IPAD / f"{name}.png")
        print(f"    {name}")

    # The share card is the app's own artwork at any size, so the iPad panel
    # uses the same render as the iPhone one rather than a second copy of it.
    name, text = CARD_PANEL
    card = RAW / "5-card.png"
    if card.exists():
        card_panel(Image.open(card).convert("RGB"), text, PANEL_IPAD).save(
            PANELS_IPAD / f"{name}.png"
        )
        print(f"    {name}")


def capture_ipad(udid: str) -> None:
    """The same four screens, on a tablet, kept in their own folder.

    The tests write to `raw/<name>.png` whatever they are running on, so the two
    devices collide twice over: the iPad run overwrites the iPhone captures on
    its way past, and moving its own results into `raw/ipad/` afterwards then
    takes those files away altogether. The first iPad run did exactly that and
    the iPhone shots had to come back out of git.

    So the iPhone captures are held aside for the length of the run and put
    back. Belt and braces against a half-finished run: the restore is in a
    `finally`.
    """
    held = Path(tempfile.mkdtemp(prefix="gita-iphone-shots-"))
    for name, _ in STILLS:
        shot = RAW / f"{name}.png"
        if shot.exists():
            shutil.copy2(shot, held / f"{name}.png")

    shots = RAW / "ipad"
    shots.mkdir(parents=True, exist_ok=True)
    try:
        capture_stills(udid)
        for name, _ in STILLS:
            (RAW / f"{name}.png").replace(shots / f"{name}.png")
    finally:
        for kept in held.iterdir():
            shutil.copy2(kept, RAW / kept.name)
        shutil.rmtree(held, ignore_errors=True)


def compose() -> None:
    """Both iPhone sets, from the same captures.

    Composed at each size rather than resized from the larger: the caption face
    and the phone's corner radius are in points, so a resize would leave the
    6.5" set slightly softer and slightly differently proportioned than the one
    beside it.
    """
    for folder, size in ((PANELS, PANEL), (PANELS_65, PANEL_65)):
        folder.mkdir(parents=True, exist_ok=True)
        print(f"  {folder.name}")
        for name, text in STILLS:
            source = RAW / f"{name}.png"
            if not source.exists():
                raise SystemExit(
                    f"error: {source.relative_to(ROOT)} is missing — capture first"
                )
            shot = Image.open(source).convert("RGB")
            device_panel(shot, text, size).save(folder / f"{name}.png")
            print(f"    {name}")

        name, text = CARD_PANEL
        source = RAW / "5-card.png"
        if source.exists():
            card = Image.open(source).convert("RGB")
            card_panel(card, text, size).save(folder / f"{name}.png")
            print(f"    {name}")


# ------------------------------------------------------------------------ main


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--stills-only", action="store_true")
    parser.add_argument("--video-only", action="store_true")
    parser.add_argument("--compose-only", action="store_true")
    parser.add_argument("--captions-only", action="store_true",
                        help="rebuild preview.mp4 from the tour already recorded")
    parser.add_argument("--ipad", action="store_true",
                        help="shoot and compose the 13\" iPad panels instead")
    options = parser.parse_args()

    RAW.mkdir(parents=True, exist_ok=True)

    if options.compose_only:
        compose()
        if (RAW / "ipad" / "1-sanskrit.png").exists():
            compose_ipad()
        return

    if options.captions_only:
        return build_preview()

    if options.ipad:
        udid = simulator(DEVICE_IPAD)
        boot(udid, DEVICE_IPAD)
        if not options.skip_build:
            print("building for testing")
            xcodebuild("-destination", f"id={udid}", "build-for-testing")
        capture_ipad(udid)
        print("composing panels")
        compose_ipad()
        print(f"\npanels -> {PANELS_IPAD.relative_to(ROOT)}")
        return

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

    print(f"\npanels -> {PANELS.relative_to(ROOT)} and {PANELS_65.relative_to(ROOT)}")
    print(f"video  -> {(VIDEO / 'preview.mp4').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
