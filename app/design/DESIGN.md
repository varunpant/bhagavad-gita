# Design system — as built

What the app actually looks like, read out of the code rather than out of the
spec. `specs.md` §9 is the brief; this is the result, and the two have diverged
in one important way (§2). When they disagree, **this file and the code win**.

Sources, all of which must change together with anything written here:

| Concern | Owner |
| --- | --- |
| Brand ramp | `Gita/Gita/Core/Design/Brand.swift` + `tools/make_brand.py` |
| Theme tokens | `Gita/Gita/Core/Design/Theme.swift` |
| Type roles | `Gita/Gita/Core/Design/Font+Roles.swift` |
| Panel columns | `Gita/Gita/Core/Design/PanelColumns.swift` |
| Reading language | `Gita/Gita/Core/Design/ReadingLanguage.swift` |
| Store panels | `design/media/README.md` + `tools/make_appstore_media.py` |

---

## 1. The one idea

**The brand is the wrapper; the reading surface is plain.**

Marigold appears in exactly four places — the app icon, the splash, the left
rail, and the App Store panels. Everywhere a reader actually reads, the app is
white paper and black ink, or black and white, and nothing else. Sepia is the
single exception, and it is a theme someone opts into.

This is a rule with scar tissue behind it: `Brand.swift` and `Theme.swift` both
carry comments about orange leaking back onto a light-theme screen. Any new
surface inherits the plain treatment unless it is one of the four.

---

## 2. Where this departs from `specs.md` §9

The spec asked for "warm paper tones with restrained saffron accents" — a warm
near-white `#FBF9F4` ground, a saffron `#C8611C` accent, warm-tinted text. The
shipped app is **pure white / pure black with `.primary` as the accent**, and
carries the warmth only in Sepia.

That is the right call and should be written down as one rather than
rediscovered: a "System" theme that tinted every control saffron read as a
themed app, not a system app. But it means §9's table is now historical. Treat
the table in §3 below as current.

---

## 3. Colour

### 3.1 The brand ramp

Four stops, warm end first. Defined once in `Brand.ramp`; mirrored byte-for-byte
in `make_brand.GROUND_LIGHT` so the icon, the splash and the store panels cannot
drift.

| Stop | Hex | Where it lands |
| --- | --- | --- |
| Yellow | `#FFD24A` | top of every full-height fill |
| Amber | `#FFA21C` | |
| Orange | `#FF6F17` | |
| Vermillion | `#E8451E` | bottom edge |

Dark variant, for the dark app icon only — `make_brand.GROUND_DARK`:
`#7A5512` → `#7A3E0A` → `#742C08` → `#6B1F0B`.

Three shapes the ramp takes, and they are not interchangeable:

- `Brand.gradient` — linear, top to bottom. Splash and rail.
- `Brand.ring` — the ramp swept round a circle, **mirrored** (`ramp + ramp.reversed()`)
  so the two ends meet in the same yellow instead of showing a vermillion seam.
  Widget rings and bars only. No rotation here; the ring view already turns its
  own stroke.
- The panel ground in `make_appstore_media.ground()` — the four stops resampled
  bicubically over the full panel height.

Ink on the ramp is **white** (`make_brand.INK`). Against a ground this bright,
white is the only thing that holds contrast the whole way down. The single
exception is the store caption — see §9.

**No pink reaches the edge of any surface.** The one pink left in the brand is
inside the mark itself, the shadow under the ग.

### 3.2 Theme tokens

Six semantic roles, resolved per theme, read through `@Environment(\.theme)`.
Never a raw hex at the point of use.

| Token | Light | Sepia | Dark |
| --- | --- | --- | --- |
| `background` | `#FFFFFF` | `#F3E9D6` | `#000000` |
| `surface` | `#FFFFFF` | `#FBF3E4` | `#1C1C1E` |
| `textPrimary` | `.primary` | `#35291A` | `.primary` |
| `textSecondary` | `.secondary` | `#6E5C43` | `.secondary` |
| `accent` | `.primary` | `#B4571A` | `.primary` |
| `divider` | `.secondary` @ 25% | `#35291A` @ 15% | `.secondary` @ 25% |

Notes that matter:

- **Sepia is a fourth theme, not a tint on light.** It cannot ride on
  `ColorScheme`, so the choice lives in `Settings` and resolves through the
  environment. `ThemePreference` is `system | light | sepia | dark`; `Theme` is
  `light | sepia | dark`.
- **`accent` is monochrome outside Sepia.** A coloured marker on a panel would
  be the only colour on the screen — which is why read-verse discs in the
  contents panel are grey rather than accent.
- The theme pins `preferredColorScheme`, which is why `.primary` and
  `.secondary` can be used directly in Light and Dark.

---

## 4. Typography

Two faces, both present on iOS and macOS so nothing is bundled:

- **Devanagari** — Kohinoor Devanagari, Light and Medium.
- **Latin** — Georgia. A serif, chosen so IAST can be set at the same size as
  the Devanagari beside it without looking smaller.

Two rules hold everywhere, and both are load-bearing:

1. **Every role is built with `relativeTo:`.** Dynamic Type — and the in-app
   text-size setting, which rides on it — scales the whole page in proportion.
   `.system(size:)` and bare `.custom(_:size:)` opt out entirely.
2. **A role is the same point size in both scripts.** Only the face changes with
   the script, never the size.

| Role | Size | Anchor | Face |
| --- | --- | --- | --- |
| `.shloka` | 27 | `.title2` | Kohinoor Light |
| `.shlokaLatin` | 27 | `.title2` | Georgia |
| `.verseReference` | 15 | `.subheadline` | Kohinoor Medium |
| `.wordDevanagari` | 17 | `.body` | Kohinoor Medium |
| `.wordLatin` | 17 | `.body` | Georgia Medium |
| `.glossDevanagari` | 16 | `.body` | Kohinoor Light |
| `.glossLatin` | 16 | `.body` | Georgia |
| `.proseDevanagari` | 17 | `.body` | Kohinoor Light |
| `.proseLatin` | 17 | `.body` | Georgia |
| `.label` | — | `.caption` | system serif, medium |
| `.labelDevanagari` | 13 | `.caption` | Kohinoor Medium |
| `.card(devanagari:size:medium:)` | fixed | none | either |

**Never pair roles across Dynamic Type anchors.** `.labelDevanagari` exists
solely because captions used to be written `isDevanagari ? .glossDevanagari : .label`
— 16pt off `.body` against 12pt off `.caption`. Close enough at Large, wrong
above it, because the two anchors grow at different rates; switching language on
a panel at an accessibility size relaid the whole thing.

`.labelDevanagari` is 13pt against `.label`'s 12: Devanagari carries matras above
and below the line, so at an equal size it reads a shade small beside a Latin
serif.

`.card(…)` is the one role with a fixed size, because the share card renders at
fixed pixels and cannot ride on Dynamic Type. It still picks its face here.

---

## 5. Space, shape, layout

| Measure | Value | Where |
| --- | --- | --- |
| Rail width | 72 | `DrawerContainer.railWidth` |
| Rail button | 72 × 52 | one per destination |
| Rail tap target | 44 × 44 min | accessibility floor |
| Reading measure | **560 max** | `ReaderView.page` |
| Page padding | 32 horizontal, 36 vertical | |
| Verse stack spacing | 30 | between blocks in a page |
| Chrome bar padding | 16 horizontal, 10 vertical | |
| Rail-edge shade | 12 wide, black 10% → clear | only along the page's left edge |
| Share card | 1080 × 1080 @ 1× | `ShareCard.side` |

**The reading column is capped at 560pt on every platform.** A wide Mac window
centres the text rather than stretching it. This is the single most visible
adaptive behaviour and the thing the iPad panel exists to show.

### 5.1 Panel columns

One rule in one place, because a panel where chapters are two across and badges
are four would not read as one screen.

| Grid | Compact | Regular |
| --- | --- | --- |
| Chapter / goal cards | 2 | 3 |
| Badges | 2 | 4 |

Keyed on **size class, not idiom**: an iPad in Split View is compact and wants a
phone's two columns.

### 5.2 The drawer

The content is **offset, never re-laid-out** — opening the rail must not re-wrap
a single line of the verse. Three consequences that are easy to undo by
accident:

- No clip on the page. Clipping meant animating how much was cut, which
  travelled visibly across the top as the rail opened.
- No drop shadow around the page. Cast all round it, it smudged grey above and
  below the rounded corners. The separation is only needed along the left edge,
  so that is the only place anything is drawn.
- The dismiss overlay is applied **before** the offset, so it travels with the
  page and leaves the rail's taps alone.

Panels are clipped to their own column to the right of the rail, so they slide
out from under it rather than sweeping across it.

### 5.3 Motion

- Drawer open/close: `.snappy(duration: 0.32)`. Panel change: `.snappy(0.30)`.
- Splash: ground resolves blurred → crisp over 2.0s (`.easeOut`), mark in at
  0.55s (`.smooth`), wordmark 180ms later at 0.5s.
- Every animation sits behind `accessibilityReduceMotion`, every material behind
  `accessibilityReduceTransparency`.
- Nothing bounces. Fades and gentle springs only.

---

## 6. Language is a surface, not a toggle

`settings.language` is the language **the reading surface is in** — headings,
captions, empty states, menus, popups, sheet titles, confirmation dialogs,
button labels and numerals, all the way down.

- The **face switches with the string**. Devanagari set in Georgia is wrong even
  when the characters are right.
- **Numerals count as language.** `1/47` in a Devanagari row is the same error as
  an English subtitle under a Sanskrit heading — `Int.devanagariDigits`.
- **Submenus and popups are part of the surface.** The one that keeps getting
  missed, because those strings are written later and in a different file.

Three deliberate exceptions: **Settings is English throughout** (it is
configuration, not reading); **VoiceOver labels for controls stay English**
(content carries its language on the string via
`AttributedString.languageIdentifier`, not on the view — SwiftUI has no
`.accessibilityLanguage` modifier); **the share card is bilingual by
construction** and carries no interface text at all.

**Anything whose length changes with the script reserves its space** —
`.lineLimit(2, reservesSpace: true)` on chapter names, `3` on badge titles. A
Devanagari chapter name is one compound where its English form is a phrase.

There is exactly **one** language switcher, in the rail.

---

## 7. Component and screen inventory

### 7.1 The rail — four destinations plus two controls

| Icon | Panel |
| --- | --- |
| `list.bullet` | Contents |
| `bookmark` | Bookmarks |
| `chart.bar` | Progress |
| `gearshape` | Settings |
| `अ` / `A` | Language toggle |
| — | Search (covers everything, rail included) |

Each button keeps its own icon whether or not its panel is showing; the icon
does not turn into a cross, which made the rail a column of identical crosses.

### 7.2 Screens

| Screen | Shape |
| --- | --- |
| **Splash** | Brand ground, ग mark at 96pt, श्रीमद् भगवद्गीता wordmark. The one full-bleed brand screen. |
| **Reader** | Horizontal pager, one verse per page. Shloka → translation → meaning → optional word-by-word. Sticky chapter/verse chrome, share bar, progress rail, `n.n` reference. Immersive mode centres the verse and removes all chrome. |
| **Contents** | 18 chapters, `read/total` in grey, tick when finished, verse chips with grey read discs; expands in place. |
| **Search** | Opaque overlay over everything. FTS5 + a semantic index (Accelerate, mean-centred vectors) — meaning, not just spelling. |
| **Progress** | Completion ring, three figures (read / streak / best), 18 chapter bars that navigate, 35 badges in four families, reset at the very bottom. |
| **Bookmarks** | Saved verses; tap to open at that verse. |
| **Settings** | English throughout. Theme (system/light/sepia/dark), text size (4 steps), language, translation / meaning / word-by-word visibility, immersive reading, share bar, daily reminder + time. |
| **Widgets** | Daily verse and progress. `Brand.ring` for the ring, the ramp along the week's bars. |

### 7.3 Badges — 35 in four families

Verse milestones (7: 1, 10, 50, 100, 250, 500, 701) · chapter completion (18,
one per chapter, each with its own symbol) · streaks (4: 7, 30, 100, 365) ·
landmark verses (6: 2.20, 2.47, 4.7, 9.22, 11.32, 18.66). Bilingual titles
(`titleSa` / `titleEn`). Locked badges shown dimmed, never hidden.

### 7.4 The share card

1080² at 1×, **always light** regardless of the reader's theme — it lands in
someone else's timeline, where a dark card looks like a mistake. Shloka at 52pt
(line spacing 22 Devanagari / 14 Latin), translation at 34pt in black @ 70%,
96pt horizontal padding, a 120 × 1 rule and the reference at 30pt medium above a
76pt bottom margin. Rendered by `ImageRenderer` over the app's own views, so it
cannot drift from the app's typography.

---

## 8. Corpus facts the design has to respect

- **701 verses, 18 chapters.** Not 700 — 13.1 is split in the source. Read the
  denominator from `chapters`; never hardcode it. (Marketing copy says "700
  verses", which is the conventional count and fine on a store panel.)
- **Shloka line breaks are semantic.** Only 11 of 701 rows carry real newlines;
  the rest break on the danda `।`, with the trailing `।।n.n।।` marker kept
  attached to the final line. The reader must not reflow them into a paragraph.
- Chapter names exist in both scripts (`name_sa`, `name_en`) and differ wildly in
  length — see §6 on reserved space.

---

## 9. The App Store panel system

Full art direction and the 15-panel shot list live in `design/media/README.md`.
This section is only the geometry, so a panel built by hand in Affinity matches
one built by `tools/make_appstore_media.py`.

### 9.1 Canvases

| Set | Canvas | Shot on | Orientation |
| --- | --- | --- | --- |
| iPhone 6.9" | 1290 × 2796 | iPhone 16 Pro Max sim (1320 × 2868, inset) | portrait |
| iPad 13" | 2752 × 2064 | iPad Pro 13-inch sim | **landscape** |
| Mac | 2880 × 1800 | the Mac app's own window, composed | 16:10 |
| Preview video | 886 × 1920 | same 0.4614 aspect as the phone panel | ≤ 28s, silent audio track required |

### 9.2 The panel, on the iPhone canvas

| Element | Value |
| --- | --- |
| Ground | brand ramp, four stops, full height |
| Caption face | Georgia **Bold**, 88pt |
| Caption top | y = 186, centre anchor, line spacing 26 |
| Caption colour | `#632206` |
| Caption lift | `#FFE7A8`, offset 0, +3 y — **under**, not a shadow |
| Caption lines | exactly two |
| Device top | caption bottom + 96 |
| Device width | 72% of canvas width, centred |
| Bezel | 16, body `#1A1412` |
| Corner radius | 10.5% of device width; inner radius = that − bezel |
| Shadow | `#6B2206`, alpha 150, offset +26 y, Gaussian blur 46 |
| Device bottom | runs off the panel edge |
| Share-card panel | square at 80% of canvas width, radius 6%, centred in the space below the caption — no phone around it |

**Why deep brown and not white for the caption.** The caption sits on the yellow
end of the ramp, which is the one place white loses contrast; at carousel
thumbnail size it goes soft and unreadable.

### 9.3 Non-negotiables

- Every shot is **wholly in one script**. A Devanagari heading over an English
  subtitle — or the reverse — is the app's own rule broken in public, and the
  fastest way to look unfinished.
- Status bar always **9:41, full bars, charged** (`simctl status_bar override`),
  so two runs cannot differ only in the clock.
- Progress shots use `-seedProgress`: chapter 1 finished, most of chapter 2,
  85 verses read, a six-day streak. Plausible and identical every run.
- Never: the system share sheet (Apple's UI, not this app's), an empty progress
  panel, an empty bookmarks list, a search with no results, or any verse the
  corpus does not contain.
- Everything is captured from the running app. No mockups, no invented screens,
  no text the app cannot actually show. Only the ground, the caption and the
  frame are composed.

### 9.4 Capture arguments

All existing debug launch arguments — nothing here needs new debug surface:

`-resetSettings` `-skipSplash` `-startInEnglish` `-immersive` `-seedProgress`
`-forceTheme` `-forceTextSize` `-openSearch` `-openMenu` `-openContentsPanel`
`-openProgressPanel` `-openBookmarksPanel` `-openSettingsPanel`

---

## 10. Accessibility floor

- Full Dynamic Type plus the in-app size slider; layout reflows, nothing clips.
- Each verse leaf is one `.accessibilityElement(children: .contain)` with
  labelled children: "Chapter 2, verse 47, Sanskrit…".
- Devanagari and Hindi carry `languageIdentifier` on an `AttributedString` so
  VoiceOver pronounces them.
- AA contrast in all three themes.
- Reduce Motion and Reduce Transparency honoured at every animation and
  material.
- 44 × 44 minimum on every rail control.

---

## 11. What a new surface inherits by default

1. `theme.background`, `theme.textPrimary`, `theme.divider` — no brand colour.
2. A role from `Font+Roles`, never a face and a number.
3. Both scripts, with the face switching alongside the string, and space
   reserved for whichever is longer.
4. A `PanelColumns` count if it is a grid.
5. `reduceMotion` around anything that moves.
6. A grep for bare string literals before it is called done.

---

## 12. `appstore-panel-template.afdesign`

An Affinity Designer document beside this file, with three artboards laid out
left to right — iPhone 1290 × 2796, iPad 2752 × 2064, Mac 2880 × 1800 — each
built to the geometry in §9.2. It is the hand-composing route when a panel
needs something the Python pipeline does not do; `make_appstore_media.py`
stays the reproducible one.

Each artboard carries, bottom to top:

| Layer | What it is |
| --- | --- |
| **Ground — brand ramp** | the four stops, vertical, full artboard |
| **Caption lift #FFE7A8 (+3y)** | the pale line under the letters |
| **Caption #632206 · Georgia Bold** | 88 / 96 / 92 pt by platform, two lines, centred |
| **Shadow — add Gaussian blur 46** | `#6B2206` at alpha 150, offset +26 y. Flat as saved: apply the blur by hand, or a Gaussian Blur live filter |
| **Device body** | `#1A1412`, radius 97 / 99 / 26, bezel 16 / 20 / — |
| **PLACE SCREENSHOT HERE** | white placeholder at the exact inner size — drop the capture in and it lands on the pixel |

To use one: replace the caption text, place the raw capture into the white
placeholder rectangle, and export the artboard at 1×. The captions are set in
Georgia rather than the app's own faces because a store caption is chrome, not
scripture — see §9.2.

Rebuild or extend it through Affinity's script SDK. Two things that cost time
the first run: a gradient fill needs an explicit `FillDescriptor` transform in
document coordinates (an identity transform makes the gradient span one pixel,
so the shape renders flat), and `ShapeRectangle.setAbsoluteSizes` takes
`(true, width, height)` — called with one argument it throws and corner radii
are then read as fractions of half the shorter side.
