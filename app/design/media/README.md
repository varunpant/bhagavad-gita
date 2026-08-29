# App Store media — the brief

Three sets, one story. This file is the art direction and the shot list; the
pictures are made from it, not the other way round.

Everything here is **captured from the running app**. No mockups, no invented
screens, no text that the app cannot actually show. The only things composed are
the ground, the caption and the device frame.

| Set | Canvas | Shot on | Orientation |
| --- | --- | --- | --- |
| iPhone 6.9" | 1290 × 2796 | iPhone 16 Pro Max simulator (1320 × 2868, inset) | portrait |
| iPad 13" | 2752 × 2064 | iPad Pro 13-inch (M5) simulator (2064 × 2752) | **landscape** |
| Mac | 2880 × 1800 | the Mac app's own window, composed onto the canvas | 16:10 |

The Mac canvas cannot be a screen grab: this machine's display is 2560 × 1080
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
- **iPad** — the whole book open at once. The rail, a panel and the reader
  together, which is the only place that layout can be seen.
- **Mac** — a desk edition. A window among windows, with room for the commentary.

---

## The panel design

One system across all three sets, so the listing reads as one product.

- **Ground.** The brand ramp from `tools/make_brand.py` — yellow → amber →
  orange → deep vermillion, top to bottom. Never pink, never at the edge.
- **Caption.** Two lines, Georgia Bold, deep brown `#632206` with a pale lift
  beneath. Deep brown rather than white: the caption sits on the yellow end of
  the ramp, which is the one place white loses its contrast at carousel size.
  Two lines because three is a paragraph and nobody reads a paragraph here.
- **Device.** Rounded frame, 16pt bezel, soft warm shadow, running off the
  bottom edge of the panel on phone and iPad. The screenshot is inset, never
  stretched.
- **Status bar.** 9:41, full bars, charged, on every shot. Apple's own
  convention, and it stops two runs differing only in the clock.
- **Seeded state.** Progress shots use `-seedProgress`: chapter 1 finished, most
  of chapter 2, 85 verses read, a six-day streak. Plausible, and identical every
  run.

### What must never appear

- A Devanagari heading over an English subtitle, or the reverse. Every shot is
  wholly in one script — the app's own rule (`app/CLAUDE.md`, *Language
  consistency*), and the fastest way to look unfinished.
- The system share sheet. It is Apple's UI, not this app's; the share card is
  rendered directly from `ShareCard` instead.
- An empty progress panel, an empty bookmarks list, or a search with no results.
- Any verse the corpus does not contain, or a translation the app cannot show.

---

## iPhone — five panels, 1290 × 2796

### 1. `iphone-1-sanskrit` — the text itself
**Caption:** All 700 verses, / in the original Sanskrit
**Screen:** Reader at **2.47** in Devanagari, the verse the whole Gita is quoted
for. Chrome visible: chapter title above, verse reference below.
**Recipe:** `-resetSettings -skipSplash`, navigate contents → chapter 2 → 2.47.
**Why it leads:** Kohinoor Devanagari at reading size, generous leading, nothing
crowding it. Someone who knows the Gita recognises the verse from the first line;
someone who does not sees a book, not an app.

### 2. `iphone-2-english` — and you will understand it
**Caption:** Every word rendered / in English
**Screen:** The same 2.47, in English: transliteration, translation, meaning.
Deliberately the same verse as panel 1 — the pair reads as one page turned,
which is the promise being made.
**Recipe:** `-startInEnglish`, same navigation.

### 3. `iphone-3-search` — find anything
**Caption:** Search the whole Gita / in an instant
**Screen:** Search overlay, query `karma`, results filling the screen, keyboard
dismissed. Now that the overlay is opaque this can be shot in **Light**; it was
previously forced to Dark to hide the page ghosting through.
**Recipe:** `-startInEnglish -openSearch`, type, then drag the results to dismiss
the keyboard.
**Why it sells:** Every result is a real verse with a real snippet, and the band
above them is the brand. It looks instant because it is.

### 4. `iphone-4-progress` — it knows where you are
**Caption:** See how far / you have come
**Screen:** Progress panel: the 12% ring over 85/701, the three figures, and the
first chapter cards below.
**Recipe:** `-seedProgress -openProgressPanel`.

### 5. `iphone-5-widgets` — it is there before you open it
**Caption:** Today's verse, / on your Home Screen
**Screen:** The daily-verse and progress widgets, rendered from the widget
extension itself, arranged on the brand ground rather than on a fabricated Home
Screen. Small ring, medium with the week's bars, and the verse widget beneath.
**Note:** the widget renders are real output; only their arrangement is composed.
If a genuine Home Screen capture becomes possible, prefer it.

---

## iPad — five panels, 2064 × 2752 portrait

**Portrait, not landscape.** The plan was landscape, for the one frame a phone
cannot show — rail, panel and reader together. The app is now locked to portrait
on every device, so that frame does not exist and the set follows the app. The
side-by-side story is still tellable in portrait, with the panel over the page.

### 1. `ipad-1-open` — the whole book, open
**Caption:** The whole Gita open at once
**Screen:** Contents panel on the left with the chapter list and its grey read
markers, the reader holding 2.47 on the right, rail down the edge with the
contents icon ringed. Three levels of the app visible in one frame.
**Recipe:** `-seedProgress -openMenu -openContentsPanel`, reader on 2.47.
**Why it leads the iPad set:** this frame is impossible on the phone. It is the
argument for the iPad edition in a single picture.

### 2. `ipad-2-reading` — the page
**Caption:** A page with room / to think
**Screen:** Reader alone, English, word-by-word list on, the measure centred at
its comfortable width with margins either side — the setting the spec asks for
on a wide screen, and visible proof the app does not simply stretch.

### 3. `ipad-3-search` — find anything
**Caption:** Every verse, / a keystroke away
**Screen:** Search overlay across the full width, `karma`, results in two
readable columns' worth of width.

### 4. `ipad-4-progress` — the whole shelf
**Caption:** Eighteen chapters, / one at a time
**Screen:** Progress panel with chapter cards **three across** and the goals grid
**four across** — the layout `PanelColumns` gives a regular size class, and a
different picture from the phone's two-up.

### 5. `ipad-5-immersive` — nothing but the verse
**Caption:** Or nothing at all / but the verse
**Screen:** Immersive reading: chrome gone, translation off, the shloka and its
meaning centred in the page.
**Recipe:** `-immersive`, translation off.

---

## Mac — five panels, 2880 × 1800

The window with rounded corners and a soft warm shadow, floating on the brand
ramp with the caption above it. Not full-bleed: a Mac app is a *window*, and the
frame is what says so.

### 1. `mac-1-reader` — a desk edition
**Caption:** The Gita, / on your desk
**Screen:** The window at ~1728 × 1080, reader on 2.47 in Devanagari, rail down
the left.

### 2. `mac-2-contents` — everything to hand
**Caption:** Every chapter, / a click away
**Screen:** Contents panel open beside the reader, chapter 2 expanded, verse
chips showing which have been read.

### 3. `mac-3-search` — instant, offline
**Caption:** Search 700 verses / without leaving the page
**Screen:** Search overlay over the window, `karma`, results listed.

### 4. `mac-4-progress` — the long read
**Caption:** A book you finish / a verse at a time
**Screen:** Progress panel: ring, figures, chapter cards three across, goals
below.

### 5. `mac-5-share` — give one away
**Caption:** Share any verse / as a card
**Screen:** The 1080² share card rendered by `ShareCard`, presented beside the
window rather than inside it — the card is the artwork, and it is square.

---

## Making them

Step 2. The capture recipes above are all existing launch arguments
(`-resetSettings`, `-skipSplash`, `-startInEnglish`, `-immersive`,
`-seedProgress`, `-forceTheme`, `-forceTextSize`, `-openSearch`, `-openMenu`,
`-openContentsPanel`, `-openProgressPanel`, `-openBookmarksPanel`), so nothing
here needs new debug surface in the app.

The existing iPhone pipeline lives in `tools/make_appstore_media.py` and writes
to `app/design/appstore/`. When the three sets are built, that folder is folded
into this one so there is a single home for store media.
