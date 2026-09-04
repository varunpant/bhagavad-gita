# App Store preview — script

The 28-second iPhone preview for **Gita**, shot by shot.

This is the plan the recording is made from. The capture itself lives in
`app/Gita/GitaUITests/ScreenshotUITests.swift` (`test9Tour`), and
`tools/make_appstore_media.py --video-only` records it and transcodes it. Change
this file first, then make the tour match it — the tour is the executable copy of
what is written here, not the other way round.

---

## 1. The frame

| | |
| --- | --- |
| Size | **886 × 1920** (portrait), the same 0.4614 aspect as the 1290 × 2796 panels, so no crop and no letterbox |
| Length | **≤ 29.5 s** — App Store Connect accepts 15–30 s. Up to 27 s of app footage plus a 2.5 s closing card |
| Frame rate | 30 fps |
| Audio | a silent stereo AAC track. **Required** — a preview with no audio stream at all is rejected |
| Poster frame | the last beat (the closing card), not the first. The store shows the poster until someone taps play, and a brand card reads better cold than a half-scrolled page of Sanskrit |
| Locale | English UI, English reading language. A second cut in Devanagari is a later job, not this one |
| Status bar | 9:41, full bars, charged — `simctl status_bar override`, already done by the script |

Two things Apple will reject, so neither appears here: no device frame drawn
around the footage, and no price, no "Download now", no App Store badge. Captions
that describe what the app does are fine, and are the point.

---

## 2. The shape of it

**Start:** the app opening on the brand ramp — the splash resolving from soft to
sharp into verse 2.47 in Devanagari. It is the one moment the app is unmistakably
*this* app and not any other reader, and it is already the first two seconds of
every launch. The tour deliberately does **not** pass `-skipSplash`.

**End:** a still closing card on the brand ground — the mark, the name, and the
one line nothing else in the video says: *No account. No ads. No tracking.
Works offline.* Held for three seconds, so it survives being the poster frame and
being the thing on screen when the loop restarts.

Between the two, six beats, each one feature, each one caption. Nothing is
demonstrated twice and nothing is on screen without a reason.

---

## 3. Shot list

Times are cumulative from the first frame of the transcode (`app_appears`
trims the black lead-in).

| # | Time | On screen | Caption (burned in) |
| --- | --- | --- | --- |
| 0 | 0.0 – 2.5 | The splash resolves from soft to sharp; the reader lands on **1.1**, in Devanagari | *All 700 verses, in the original Sanskrit* |
| 1 | 2.5 – 5.2 | A scroll down the verse: translation, meaning, and the word-by-word gloss | *Translation, meaning, and every word explained* |
| 2 | 5.2 – 9.4 | The rail opens; the **script switch** turns the same verse into English and transliteration | *Read in Sanskrit or in English* |
| 3 | 9.4 – 12.1 | **Contents**, open on the chapter being read: the verse grid, read progress in the fill, **gold rings** on 1.1, 1.28, 1.47 | *Every chapter, every verse — the famous ones ringed in gold* |
| 4 | 12.1 – 17.5 | **Search** from the rail: `karma` typed, results land, the keyboard drops away, the first result opens its verse | *Search by word, meaning or number — instantly, offline* |
| 5 | 17.5 – 22.9 | On that verse: the **bookmark** fills, then the share popup offers Link or Image. Stops there | *Keep a verse, or share it as a card* |
| 6 | 22.9 – 27.4 | **Progress**: the completion ring and the figures, then down to the chapter cards and the goals | *Read at your own pace — thirty-five goals on the way* |
| 7 | 27.4 – 29.8 | The closing card on the brand ground: the mark, the name, the promise | *No account. No ads. No tracking. Works offline.* |

Delivered: **29.8 s**, 886 × 1920, 30 fps, h264 + a silent AAC track, at
`app/design/appstore/video/preview.mp4`.

### What the takes taught

Eleven of them. None of this was in the first draft of the script, and each cost
a four-minute run of the simulator to find:

- **Search does not put the rail away.** `Drawer.search()` deliberately leaves
  the rail where it was, so closing search returns the reader to the panel they
  had open. That also means the page underneath is still `disabled`, and beat 5's
  bookmark could not be tapped. Choosing a search *result* is what clears all
  three — rail, panel, search — in one move, so beat 4 now ends by opening a
  verse rather than by closing search. It is a better shot for the same reason it
  is a better fix: search that goes somewhere.
- **The reader is a pager, so every identifier exists three times.** The verse to
  the left and the verse to the right are built and in the accessibility tree,
  and `app.buttons["shareButton"]` took the first of them — off screen at
  x = -170, and disabled. The tour picks the hittable one.
- **A caption has to be timed to the payoff, not to the beat.** Timed from the
  start of a beat, "Read in Sanskrit or in English" played over a rail sliding
  open and "the famous ones ringed in gold" over a page of prose. Each beat now
  records a second mark — the moment its screen is actually up — and the caption
  runs from there.
- **A tap 0.4 s after the rail is asked to open lands on nothing.** The language
  switch silently did not happen, and the caption claimed it anyway. The tour now
  waits for the header to read `Chapter 1 · Verse 1` before showing that caption:
  the verse reference is written in whichever language is on, so it is the proof.
- **`.scrollDismissesKeyboard(.interactively)` follows a drag *down*.** Dragging
  the results up scrolled them and left the keyboard over the bottom third —
  which is exactly where the caption goes.
- **Half the take is accessibility work, not app.** Roughly a second per query
  or tap, so the actions that survive are the ones that put a feature on screen.
  Two were cut outright: the tap through to the next verse (paging is shown twice
  over by contents and search) and the tap on a chapter row (the contents opens
  on the chapter being read, already expanded, rings already visible).
- **Scrolling a 700-row panel is most of a take.** Reaching 2.47 in the contents
  cost about eight seconds of swipes and accessibility snapshots for one tap. The
  contents beat now holds still and lets search do the travelling.

### The gold rings — beat 3 is doing two jobs

`FamousVerses.all` is a hand-picked set of **eighty verses** — 2.20, 2.47,
4.7, 9.22, 18.66 and the rest — the ones a reader is most likely to arrive
already knowing. In the contents they carry a gold ring around the verse number.

It is worth its own half-second of the twenty-eight because it is the one feature
that answers "where do I even start with a 700-verse book", and because no
competitor's contents list does it. Two things the shot has to make legible, both
of which the in-app guide has to explain in words:

- The ring is about **the verse**, not about the reader. It is the same on a
  first launch as on the thousandth; nothing here is earned or reset.
- Progress is the **fill** of the circle, not the ring around it. The shot should
  show a ringed verse that is unread and a plain verse that is read, so the two
  cannot be confused.

Tapping through to 2.47 — itself a ringed verse, and the one the whole Gita is
quoted for — is what ties the beat to the opening frame.

### What is left out, and why

- **Immersive reading, themes, text size** — real features, but each is a screen
  that looks like the reader with something removed. They read as nothing
  happening. They belong in the screenshot panels and the in-app guide.
- **Widgets** — showing them means leaving the app for the home screen, which
  costs four seconds of the twenty-eight and breaks the thread.
- **The welcome / guide** — it is an onboarding flow. Nobody buys an app for its
  onboarding.
- **The share sheet itself** — that is Apple's UI, not ours. Beat 5 stops on the
  app's own popup, one tap short of it. Both rows are `ShareLink`s, so the
  popover is dismissed by tapping outside rather than by pressing either.
- **A badge earned on camera.** It was in the first draft of this script and it
  is not filmable: `-seedProgress` leaves 85 verses read, and the nearest goal is
  fifteen verses away — far more reading than twenty-eight seconds holds. Beat 6
  shows the goals that are already won instead.

---

## 4. The captions

Burned into the video with `ffmpeg drawtext` at transcode time, so the caption
copy lives in `make_appstore_media.py` beside the `STILLS` captions and can be
changed without re-recording.

- **Placement:** a band across the bottom sixth, clear of the home indicator.
  Never over the top third — that is where the verse reference and the rail sit.
- **Ground:** the brand ground at ~85% opacity behind the text, not text floating
  on the page. A caption that half-disappears into a paragraph of Devanagari is
  worse than no caption.
- **Type:** Georgia Bold, the same face as the still panels, deep brown on the
  light ground. One line where possible, never more than two.
- **Timing:** each caption appears ~0.3 s after its beat starts and leaves 0.3 s
  before it ends, so a caption never straddles a transition.
- **Language:** English throughout, including over beat 0's Devanagari page —
  the caption is what tells a non-reader what they are looking at.

---

## 5. Where to record it: **the simulator**

Record on the **iPhone 16 Pro Max simulator**, which is what
`make_appstore_media.py` already does, for four reasons:

1. **It is reproducible.** The tour is a UI test. A caption change, a new beat,
   or a redesigned panel is one command away from a new video, and two runs
   differ in nothing — not the clock, not the battery, not the pacing.
2. **The pixels are right.** `simctl io recordVideo` writes native device
   resolution, and the status bar is overridden to Apple's 9:41 convention. A
   hand-held recording of a real phone gives you a real clock, a real battery
   percentage and whatever notification arrives mid-take.
3. **Debug launch arguments.** `-seedProgress` fills the rings and unlocks the
   goals so beat 6 has something to show; `-resetSettings` guarantees a clean
   first-run state. On a real device you would have to read a few hundred verses
   by hand before each take, or ship a debug build to it and drive it manually.
4. **This app has nothing that needs real hardware.** No camera, no ARKit, no
   Metal, no Live Activities in the tour. Search, the database and the share card
   all run identically in the simulator; haptics do not record either way.

**Use a real device only if** a beat is ever added that the simulator cannot
show — home-screen widgets in their real setting, or anything involving system
sharing to another app. Then: connect the iPhone, QuickTime → File → New Movie
Recording → pick the phone, record, and crop to 886 × 1920. Expect several takes
and a fingertip in shot.

**Not** a screen recording from the phone's own Control Center: it captures at
device resolution but starts and ends with the recording UI, and the red status
bar appears in the first frames.

---

## 6. Making it

```bash
.venv/bin/python tools/make_appstore_media.py --video-only
```

Which does: boot the 6.9" simulator → override the status bar → build the UI test
target → start `simctl io recordVideo` → run `test9Tour` → SIGINT the recorder
(never `kill`; an unfinalised `.mov` will not play) → trim the black lead-in →
scale to 886 × 1920 → burn the captions → mux a silent stereo track → write
`app/design/appstore/video/preview.mp4`.

Output: `tour.mov` (raw, ~35 MB, not uploaded) and `preview.mp4` (the upload).

### How the captions know when to appear

The sleeps in `test9Tour` are not the timings. Every tap costs an animation and
every query costs a layout pass, so by the last beat a schedule guessed from the
source is seconds out — which is a caption over the wrong screen.

So the run measures itself. `test9Tour` writes `raw/tour-timeline.json` — one
entry per beat, in seconds from the moment the app took the screen — and the
script maps those offsets onto the movie, anchored on `app_appears`. The copy
stays in `make_appstore_media.py` (`CAPTIONS`, keyed by beat name); the test only
says *when*, never *what*. Rewriting a line does not rebuild a test target.

If the take overruns 27.4 s, the whole thing is played back very slightly faster
rather than having its last beat cut off — a tenth quicker reads as pace, a
missing progress screen reads as a shorter app. Past 1.25× the script refuses
and asks for the holds to be shortened instead, because by then it reads as
hurry.

Iterating on the captions does not need the simulator at all:

```bash
.venv/bin/python tools/make_appstore_media.py --captions-only
```

The delivered take ran 33.1 s and plays at 1.21×. That is inside the 1.25 ceiling
but not comfortably: another beat, or a slower machine, means shortening the
holds rather than raising the ceiling.

which rebuilds `preview.mp4` from the `tour.mov` and the timeline already on
disk, in about fifteen seconds.

### One thing the tour turns on

`showWordByWord` is **off** by default — most readers want the verse, not the
grammar. The tour launches with `-showWordByWord`, because "every word explained"
is one of the seven things this video says the app does, and a caption over a
screen that does not show it is a claim the app has not kept. Everything else in
the take is the app as it arrives.

### Uploading

App Store Connect → the 6.9" iPhone set → App Previews. One preview is enough;
the slot accepts three. Set the poster frame to the closing card. The same video
is reused for 6.5" automatically.
