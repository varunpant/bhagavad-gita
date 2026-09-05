# App Store media — the brief

One home for store media, and this is it. There were two: an art-direction brief
at `app/design/media/README.md` that planned three platform sets and produced
none, and this folder, which has a pipeline and ships the files. The brief's
plan was to fold this folder into that one; it has gone the other way, because
this is the half that runs. Everything worth keeping from it is below.

Everything here is **captured from the running app**. No mock-ups, no invented
screens, no text the app cannot actually show. The only things composed are the
ground, the caption and the device frame.

| Set | Canvas | Shot on | State |
| --- | --- | --- | --- |
| iPhone 6.9" | 1290 × 2796 | iPhone 16 Pro Max simulator | **built** — `iphone-6.9/` |
| iPhone 6.5" | 1284 × 2778 | composed from the same captures | **built** — `iphone-6.5/` |
| iPad 13" | 2064 × 2752 portrait | iPad Pro 13-inch (M4) simulator | **built** — `ipad-13/` |
| Preview video | 886 × 1920, ≤30s | iPhone 16 Pro Max simulator | **built** — `video/preview.mp4` |
| Mac | 2880 × 1800 | the Mac app's own window, composed | **not built** |

**Portrait on iPad, not landscape.** The plan was landscape, for the one frame a
phone cannot show — rail, panel and reader together. The iPhone is locked to
portrait (`e4df93e`) and the iPad is not — it takes all four orientations, which
is what makes it a full-screen iPad app rather than a letterboxed phone one. The
set is portrait anyway: it is the shape the store shows a tablet in, and the
side-by-side story is tellable in portrait with the panel over the page.

The Mac canvas cannot be a screen grab: the display here is 2560 × 1080
ultrawide and App Store Connect wants 16:10. The window is captured and placed.

---

## The through-line

A reader opening the store page has one question — *is this a serious edition of
the Gita, or another quote app?* Every panel answers it the same way: by showing
the text, set properly, with the app's own furniture around it.

So the first panel of every set is the scripture itself, large, in Devanagari.
Nothing sells this app better than the shloka does.

The order after that is the same argument in every set:

1. **It is the real text.** Devanagari, the original.
2. **You will understand it.** English, word by word.
3. **You can find anything in it.** Search, instant, offline.
4. **It knows where you are.** Progress, streaks, goals.
5. **It is yours to keep and to give.** Bookmarks, share cards, widgets.

Platform sets differ in what they *emphasise*, never in what they claim:

- **iPhone** — the book in a pocket. One column, one verse, a thumb's reach.
- **iPad** — the whole book at once. The rail, a panel and the reader together.
- **Mac** — a desk edition. A window among windows, with room for the commentary.

---

## The panel design

One system across every set, so the listing reads as one product.

- **Ground.** The brand ramp, imported from `tools/make_brand.py` rather than
  repeated — yellow → amber → orange → deep vermillion, top to bottom. Never
  pink, never at the edge.
- **Caption.** Two lines, Georgia Bold, deep brown `#632206` with a pale lift
  beneath. Deep brown rather than white: the caption sits on the yellow end of
  the ramp, which is the one place white loses its contrast at carousel size.
  Two lines because three is a paragraph and nobody reads a paragraph here.
- **Device.** Rounded frame, soft warm shadow, running off the bottom edge of
  the panel. The screenshot is inset, never stretched. Frame width and corner
  radius are parameters — a 13" screen in a phone-shaped frame with phone-round
  corners reads as a stretched iPhone.
- **Everything is a fraction of the panel.** Type size, bezel, blur and offsets
  all scale with the canvas. They were once pixel constants tuned to a 1290-wide
  panel, and on a 2064-wide iPad panel the same numbers made a headline into a
  label.
- **Status bar.** 9:41, full bars, charged, on every shot — Apple's convention,
  and it stops two runs differing only in the clock.
- **Seeded state.** Progress shots use `-seedProgress`: chapter 1 finished, most
  of chapter 2, 85 verses read, a six-day streak. Plausible, and identical every
  run.
- **iPad is shot at extra-large reading size.** The column is capped at 680pt so
  a line never runs the width of the screen, which is right for reading and
  wrong for a store panel: at default size the page is a small block of text
  adrift in white. The size is a real setting, not a mock-up.

### What must never appear

- A Devanagari heading over an English subtitle, or the reverse. Every shot is
  wholly in one script — the app's own rule (`app/CLAUDE.md`, *Language
  consistency*), and the fastest way to look unfinished.
- The system share sheet. It is Apple's UI, not this app's; the share card is
  rendered directly from `ShareCard` instead.
- An empty progress panel, an empty bookmarks list, or a search with no results.
- Any verse the corpus does not contain, or a translation the app cannot show.

---

## iPhone — five panels

What is built, and the caption each carries:

| File | Caption | Screen |
| --- | --- | --- |
| `1-sanskrit` | All 700 verses, / in the original Sanskrit | Reader at **2.47** in Devanagari — the verse the whole Gita is quoted for |
| `2-english` | Every word rendered / in English | The same 2.47 in English: transliteration, translation, meaning. Deliberately the same verse, so the pair reads as one page turned |
| `3-search` | Search the whole Gita / in an instant | Search overlay, `karma`, results filling the screen, keyboard dismissed |
| `4-progress` | See how far / you have come | The 12% ring over 85/701, the three figures, the first chapter cards |
| `5-card` | Share any verse / as a card | The 1080² share card, rendered by `ShareCard` itself — square, so it gets no device frame |

**One panel the brief asked for and this does not build:** a widgets panel —
the daily-verse and progress widgets arranged on the brand ground. It would
replace or follow `5-card`. Widget renders cannot be screenshotted out of the
extension, so it means drawing them, which is what `WelcomeDaily` already does
for the guide.

## iPad — the same five, shot on the tablet

Not the phone's captures scaled: the layout genuinely differs — the progress
panel goes to three chapter columns on a regular size class, and that different
picture is the argument for the iPad edition.

## Mac — not built

Five panels planned: reader, contents beside the reader, search, progress, and
the share card beside the window. The window with rounded corners and a soft
warm shadow, floating on the brand ramp with the caption above it. Not
full-bleed: a Mac app is a *window*, and the frame is what says so. Nothing
captures a Mac window yet — `make_appstore_media.py` drives simulators.

---

## Making them

```bash
.venv/bin/python tools/make_appstore_media.py                 # stills + video
.venv/bin/python tools/make_appstore_media.py --stills-only
.venv/bin/python tools/make_appstore_media.py --ipad          # the 13" set
.venv/bin/python tools/make_appstore_media.py --compose-only  # redraw panels
.venv/bin/python tools/make_appstore_media.py --captions-only # redraw the video's captions
```

The capture recipes are all existing launch arguments — `-resetSettings`,
`-skipSplash`, `-startInEnglish`, `-immersive`, `-seedProgress`, `-forceTheme`,
`-forceTextSize`, `-showWordByWord`, `-openSearch`, `-openMenu`,
`-openContentsPanel`, `-openProgressPanel`, `-openBookmarksPanel` — so a new
panel needs no new debug surface in the app.

The captures themselves live in `GitaUITests/ScreenshotUITests`, which is **not**
part of the test suite: it drives the app and writes files. Read it first if a
panel is showing the wrong screen.

The preview video has its own shot list, in `video/preview-script.md`.

Guide art for the in-app welcome is a different job with a different pipeline —
`tools/make_welcome_art.py`, shooting into `app/design/media/welcome/`. It is not
store media and does not belong here.
