# Bhagavad Gita — App Specification

**Working title:** Gita (bhagwadgita.info)
**Document status:** v1 draft — for build planning
**Last updated:** 2026-08-08
**Owner:** Varun

---

## 1. Summary

A native, offline-first reading app that lets anyone move calmly through all 700
verses of the Bhagavad Gita — the original Sanskrit śloka alongside Hindi and
English translation and commentary. It is a companion to the existing website
(`bhagwadgita.info`) and draws on the **same content source** (`srimad.csv`),
compiled into a bundled read-only **SQLite** database that ships inside the app.

The product is one **SwiftUI universal app** that runs on iPhone, iPad, and Mac,
sharing a single codebase and a single data file. The experience is
typography-first and unhurried: reading the Gita should feel like opening a
well-made book, not a database browser.

### Design pillars

1. **Reverent calm.** Spacious, quiet, paper-like. The text is the interface.
2. **Effortless flow.** Continuous, gesture-driven scrolling through 700 verses
   with zero friction and instant response, fully offline.
3. **Read your way.** Show only the languages you want; adjust type, theme, and
   script to taste; pick up exactly where you left off.
4. **Native on every screen.** Genuinely at home on a phone, a tablet, and a Mac
   — not a stretched phone layout.

---

## 2. Goals and non-goals

### Goals (v1)

- Deliver the complete Gita — 18 chapters, 700 verses — fully offline.
- Present each verse's four content blocks: Sanskrit mūla śloka, Hindi
  translation (Swami Ramsukhdas), Hindi commentary (Swami Chinmayananda), and
  English translation (Swami Sivananda).
- Continuous scroll reading plus fast jump-to-verse and full-text search.
- Personalization: bookmarks, reading progress/resume, font size, theme,
  language visibility, Devanagari font choice.
- Daily verse with home/lock-screen widgets, an optional daily notification, and
  polished share cards.
- Audio recitation of the Sanskrit and per-language toggles (subject to the
  content dependency in §12).
- A single build pipeline that regenerates the app's database from `srimad.csv`.

### Non-goals (v1)

- No account system, cloud login, or server backend. Sync, if any, is via
  iCloud/CloudKit for the user's own private data only (see §10).
- No user-generated content, comments, or social feed.
- No in-app purchases or ads in v1 (revenue model is out of scope here).
- No additional translations/commentaries beyond the four already in the data
  set (a data-model hook is provided for future ones — see §5).
- No Android/Windows/Web build. The website already covers the web surface.

---

## 3. Platforms and devices

| Platform | Minimum | Target | Notes |
| --- | --- | --- | --- |
| iOS (iPhone) | iOS 17 | iOS 18+ | Primary form factor; one-hand reading. |
| iPadOS | iPadOS 17 | iPadOS 18+ | Multi-column, keyboard + pointer support. |
| macOS | macOS 14 Sonoma | macOS 15+ | Native Mac (Apple Silicon) via the same SwiftUI target; menu bar, resizable window, sidebar. |

Single universal SwiftUI app target with platform-conditional layout. Apple
Silicon Mac build is native SwiftUI (not Catalyst) where feasible; Catalyst is
an acceptable fallback if a specific Mac capability is missing. All three
platforms ship the identical bundled database.

---

## 4. Architecture

### 4.1 Stack

- **UI:** SwiftUI, one universal target, adaptive layout via size classes and
  `NavigationSplitView`.
- **State:** Swift Observation (`@Observable`) with a thin MVVM seam; no heavy
  third-party state framework.
- **Data access:** [GRDB.swift](https://github.com/groue/GRDB.swift) over
  **SQLite**. The Gita content database is **read-only and bundled**; the user's
  personal data (bookmarks, progress, settings) lives in a **separate writable**
  store.
- **Search:** SQLite **FTS5** virtual table built at content-compile time for
  instant full-text search across all languages.
- **Audio:** `AVFoundation` (`AVAudioPlayer` / `AVPlayer`) with background-audio
  and lock-screen "Now Playing" controls.
- **Widgets:** WidgetKit + App Intents (daily verse, quick-open).
- **Persistence for prefs/bookmarks:** GRDB writable DB in App Support, mirrored
  to a shared **App Group** container so widgets can read the daily verse and
  progress. Optional CloudKit private-database sync (§10).

### 4.2 Two-database split

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│  gita.sqlite  (bundled, RO)  │     │  user.sqlite  (App Support)   │
│  • verses, chapters          │     │  • bookmarks                  │
│  • FTS5 index                │     │  • reading_progress           │
│  • audio manifest            │     │  • settings / preferences     │
│  built from srimad.csv       │     │  • daily_verse_history        │
└─────────────────────────────┘     └──────────────────────────────┘
        read-only, versioned                 read/write, user-owned
```

Keeping content and user data separate means content updates (a corrected
translation, added transliteration) ship as a new bundled DB on app update
without ever touching or migrating the user's bookmarks.

### 4.3 Content pipeline (build-time)

A small script — `tools/build_db.py` (mirrors the existing `main.py` conventions)
— reads `srimad.csv` and emits `gita.sqlite`:

1. Read each row (`counter`, `chapter`, `sutra`, `mool_shloka`, `hindi`,
   `Commentary`, `english_translation`).
2. Normalize whitespace/line breaks exactly as the site does (preserve the śloka
   line breaks).
3. Insert into `verses`; join chapter names from `data/chapters.toml`.
4. Populate the FTS5 index (Sanskrit, Hindi, English, transliteration when
   available).
5. Stamp a `content_version` and `built_at` in a `meta` table.
6. Run `VACUUM` and `PRAGMA optimize`; the DB ships in the app bundle.

`srimad.csv` and `data/chapters.toml` remain the **single source of truth**,
shared with the website. The app never edits content at runtime.

---

## 5. Data model

### Content database (`gita.sqlite`, read-only)

**chapters**

| column | type | notes |
| --- | --- | --- |
| id | INTEGER PK | 1–18 |
| number | INTEGER | display number (== id) |
| name_sa | TEXT | e.g. अर्जुनविषादयोग |
| name_en | TEXT | e.g. "The Despondency of Arjuna" |
| verse_count | INTEGER | verses in this chapter |

**verses**

| column | type | notes |
| --- | --- | --- |
| id | INTEGER PK | global position (1–700) |
| chapter | INTEGER FK | → chapters.id |
| sutra | INTEGER | verse number within chapter |
| position | INTEGER | global running order |
| sanskrit | TEXT | mūla śloka (Devanagari, line breaks preserved) |
| transliteration | TEXT NULL | IAST — nullable, filled when sourced (§12) |
| hi_translation | TEXT | Swami Ramsukhdas |
| hi_commentary | TEXT | Swami Chinmayananda |
| en_translation | TEXT | Swami Sivananda |
| audio_file | TEXT NULL | recitation asset key — nullable (§12) |

*Unique index on (chapter, sutra); ordered index on position.*

**verses_fts** — FTS5 virtual table over `sanskrit`, `transliteration`,
`hi_translation`, `hi_commentary`, `en_translation`, contentless-linked to
`verses` by rowid.

**meta** — `content_version`, `built_at`, `source_checksum`.

**Extensibility hook:** to support additional translations later without schema
churn, an optional `translations(verse_id, source_key, lang, role, body)` table
can hold arbitrary (translator × role) blocks; v1 keeps the four fixed columns
for simplicity and can migrate to the table form in v2.

### User database (`user.sqlite`, read/write)

- **bookmarks**(verse_id, created_at, note NULL, color NULL)
- **reading_progress**(verse_id, scroll_offset, updated_at) — last-read anchor
- **settings**(key, value) — theme, font size, language visibility, script,
  audio prefs, notification time
- **daily_verse_history**(date, verse_id) — deterministic, so widget and app agree

---

## 6. Information architecture and navigation

```
Gita
├── Today            (daily verse, continue reading, "on this day")
├── Read             (chapter list → chapter → continuous verse reader)
├── Search           (full-text, filters by language/chapter)
├── Bookmarks        (saved verses, notes)
└── Settings         (appearance, languages, audio, notifications, about)
```

Navigation adapts by device:

- **iPhone:** bottom `TabView` (Today · Read · Search · Bookmarks · Settings). The
  reader is a full-screen push.
- **iPad / Mac:** `NavigationSplitView` — persistent left **sidebar** (the five
  destinations + expandable chapter tree), a **content column** (chapter index or
  search results), and the **reader** as the detail column. On Mac this also gets
  a full menu bar and keyboard shortcuts.

---

## 7. Screen specifications

### 7.1 Today (home)

The landing surface and the emotional anchor of the app.

- **Verse of the day** as a large, quiet card: chapter name, verse reference
  (e.g. "2.47"), the Sanskrit śloka, and a chosen translation. Tapping opens it
  in the reader. Deterministic per calendar day (seeded by date) so it matches
  the widget and never repeats until the cycle completes.
- **Continue reading** card: resumes at the exact last-read verse and scroll
  position.
- Secondary quick actions: "Random verse," "Start from the beginning
  (Chapter 1)," jump to a specific chapter/verse.
- Optional gentle greeting tied to time of day.

### 7.2 Read → chapter list

- The 18 chapters as an elegant vertical list. Each row: chapter number in a
  restrained numeral, Sanskrit name, English name, and verse count.
- Subtle progress affordance per chapter (how far the user has read).
- Search field pinned at top scrolls to reveal.

### 7.3 Reader (the core)

The heart of the app — a **continuous, single-column scroll** through verses.

- Verses render as stacked "leaves." Each verse block shows, in order and
  according to the user's language visibility settings:
  1. **Verse reference** + chapter name (sticky mini-header while that verse is
     on screen).
  2. **Sanskrit mūla śloka** — centered, larger Devanagari, line breaks intact.
  3. **Transliteration (IAST)** — optional, muted, directly under the Sanskrit.
  4. **Hindi translation**, **English translation**, then **Hindi commentary**
     — each labeled with its author, commentary visually de-emphasized
     (indent/smaller) so translation reads first.
- **Scroll model:** buttery, lazy (`LazyVStack` in a `ScrollView` with
  `ScrollPosition`), so all 700 verses feel like one document but only visible
  leaves render. Scroll position is continuously persisted.
- **Per-verse actions** (long-press or a subtle trailing control): bookmark,
  copy, share card, play audio, "jump to verse."
- **Reading affordances:** tap the center to toggle a minimal chrome (top bar +
  progress rail) for distraction-free reading; a thin progress indicator shows
  position within the chapter and within the whole Gita.
- **Cross-chapter continuity:** scrolling past the last verse of a chapter flows
  into a slim chapter divider then the next chapter — the whole Gita is one
  continuous scroll, mirroring `rel=prev/next` on the site.

### 7.4 Search

- Single search field; results update live using FTS5.
- Each result: verse reference, chapter, and a snippet with the matched term
  highlighted (uses FTS5 `snippet()`), showing which language matched.
- Filters: by language (Sanskrit / Hindi / English / commentary) and by chapter.
- Devanagari and Latin input both work; transliteration column lets an English
  speaker find a śloka by its IAST spelling once that data exists.
- Recent searches; empty state suggests a few well-known verses (e.g. 2.47).

### 7.5 Bookmarks

- List of saved verses with optional colored tags and free-text notes.
- Swipe to remove; tap to open in the reader at that verse.
- Sort by chapter order or by date added; filter by tag color.

### 7.6 Settings

Grouped: **Appearance** (theme: system / light / sepia / dark; font size slider
with live preview; Devanagari font choice; line spacing), **Languages** (toggle
each of Sanskrit, transliteration, Hindi translation, Hindi commentary, English —
this drives what the reader renders), **Audio** (autoplay, continuous play,
download recitation), **Daily verse** (notification on/off and time), **About**
(content sources and attributions, link to `bhagwadgita.info`, content version,
credits to the translators, licensing/acknowledgements).

---

## 8. Reading experience details

- **Language visibility** is a first-class setting, applied globally and instantly
  in the reader. A reader who wants only Sanskrit + English gets exactly that,
  with vertical rhythm re-flowing cleanly.
- **Devanagari rendering** must be correct: proper conjunct shaping and matras.
  Use a high-quality Devanagari face (e.g. a Noto Serif Devanagari–class font)
  bundled with the app so rendering is identical across devices — this mirrors the
  website's care about Raqm-correct Devanagari in its share cards.
- **Śloka line breaks are semantic** — preserve them exactly as stored (the data
  keeps them; the reader must not reflow them into a paragraph).
- **Typography scale** respects Dynamic Type; the in-app font slider layers on top
  for finer control while reading.
- **Copy / share** emits nicely formatted text (reference + śloka + translation +
  `bhagwadgita.info` link) and an image share card.

---

## 9. Visual design system — "Calm & modern minimal"

The chosen direction: serene, spacious, typography-first; warm paper tones with
restrained saffron accents; a premium, quiet reading feel.

### 9.1 Color

Semantic tokens, resolved per theme (Light / Sepia / Dark / System):

| Token | Light | Sepia | Dark |
| --- | --- | --- | --- |
| `background` | near-white warm (#FBF9F4) | aged paper (#F3E9D6) | near-black warm (#14110E) |
| `surface` | #FFFFFF | #FBF3E4 | #1E1A16 |
| `textPrimary` | #211D18 | #35291A | #ECE6DA |
| `textSecondary` | #6B6155 | #6E5C43 | #A79E90 |
| `accent` (saffron) | #C8611C | #B4571A | #E6873C |
| `divider` | rgba warm 8% | rgba warm 10% | rgba warm 12% |

Saffron is used **sparingly** — active states, the daily-verse accent, the
progress rail — never as a fill behind text. Gold is reserved for the app icon
and occasional dividers, echoing `krishna.png`'s gold-on-black line art.

### 9.2 Typography

- **Devanagari (Sanskrit / Hindi):** a serif Devanagari face, generous size and
  line height for the śloka; slightly smaller for Hindi translation/commentary.
- **Latin (English / UI):** a warm humanist serif for body reading (e.g. a
  New York–class serif) paired with the system sans for controls and labels.
- Clear typographic hierarchy: śloka (display) → translations (body) → commentary
  (body-muted, indented) → labels/captions (small caps or tracked uppercase).

### 9.3 Space, shape, motion

- Generous margins and vertical rhythm; one column of comfortable measure even on
  wide Mac windows (text column capped, centered).
- Soft corner radii, hairline dividers, near-flat surfaces (no heavy shadows).
- **Motion is subtle and physical:** fades and gentle springs, a soft parallax on
  the chapter divider, chrome that eases in/out on tap. Never bouncy or loud.
  Respects Reduce Motion.
- Optional **immersive reading**: chrome fully recedes, background dims slightly,
  only text remains.

### 9.4 App icon and identity

Gold Krishna/flute line-art motif on a deep warm ground, consistent with the
site's existing `krishna.png` identity; simplified for small sizes.

---

## 10. Personalization and data ownership

- All personal data (bookmarks, notes, progress, settings) is stored locally in
  `user.sqlite` and belongs to the user.
- **Optional iCloud sync** via CloudKit **private** database keeps bookmarks,
  progress, and settings consistent across the user's own iPhone/iPad/Mac. It is
  private, off by default or clearly user-controlled, and requires no login
  beyond the device Apple ID. No third-party servers.
- An **App Group** shared container exposes the current daily verse and last-read
  reference to widgets.

---

## 11. Daily verse, widgets, notifications, sharing

- **Daily verse selection** is deterministic from the calendar date (seeded
  shuffle over 1–700) so the app, the widget, and the notification always agree,
  and history is recorded in `daily_verse_history`.
- **Widgets (WidgetKit):** small (reference + short line), medium (śloka +
  translation), lock-screen (reference + one line). Tapping deep-links straight
  into that verse in the reader. Optional "Continue reading" widget.
- **Notification:** one optional gentle daily reminder at a user-set time,
  surfacing the day's verse. No other notifications.
- **Share cards:** reuse the website's card concept (chapter name, verse number,
  śloka, English translation, domain) rendered on-device as a shareable image,
  plus a text share. This is a direct analogue of `tools/make_og_images.py`.

---

## 12. Audio and transliteration — content dependency

Two requested capabilities are **not present in the current dataset** and are
explicit dependencies, not code problems:

- **Sanskrit recitation audio.** Requires sourcing/licensing 700 per-verse audio
  files (or chapter-level files with per-verse markers). The schema is ready
  (`verses.audio_file`, an audio manifest, `AVFoundation` playback with
  lock-screen controls and optional continuous play). **Decision needed:** source,
  licensing, and whether audio is bundled or downloaded on demand.
- **IAST transliteration.** The `transliteration` column and FTS coverage are
  designed in, but the Latin transliteration of each śloka must be generated (a
  Devanagari→IAST transliterator over the existing Sanskrit, then a proofing pass)
  or sourced. Until then the app renders gracefully without it.

Recommendation: ship v1 reading fully, and treat audio + transliteration as a
fast-follow once the content is secured — the data model and UI already
accommodate both without rework.

---

## 13. Adaptive layout across phone, tablet, and Mac

| Aspect | iPhone | iPad | Mac |
| --- | --- | --- | --- |
| Navigation | bottom tab bar | split view + sidebar | sidebar + menu bar |
| Reader | single full-width column | centered column with margins; optional two-pane (index + reader) | centered column in resizable window; multiple windows |
| Input | touch, gestures | touch, pointer, keyboard | pointer, full keyboard shortcuts |
| Chrome | tap to toggle | toolbar + hover controls | toolbar + menus (⌘F search, ⌘D bookmark, ⌘→/← next/prev verse) |
| Widgets | home + lock screen | home screen | notification center / desktop |

The reading **column width is capped** everywhere so lines stay a comfortable
measure — a wide Mac window centers the text rather than stretching it.

---

## 14. Accessibility

- Full **Dynamic Type** support plus the in-app size slider; layout reflows, no
  clipping.
- **VoiceOver:** every verse block is a well-labeled element ("Chapter 2, verse
  47, Sanskrit…," etc.); language labels announced; controls have clear traits.
- **Contrast** meets WCAG AA in every theme; saffron accent is checked against
  each background.
- **Reduce Motion** and **Reduce Transparency** honored.
- Devanagari read correctly by VoiceOver where supported; provide the English
  translation as an accessible alternative path.

---

## 15. Offline, performance, privacy

- **Fully offline.** The entire Gita ships in the bundle; no network needed to
  read, search, bookmark, or see the daily verse. (Audio, if download-on-demand,
  is the only networked feature.)
- **Performance targets:** cold launch to readable content < 1s on recent
  hardware; 60/120fps scrolling via lazy rendering; search results < 50ms via
  FTS5.
- **Privacy-first:** no accounts, no tracking, no ads, no third-party analytics
  by default. If any usage analytics are added, they are on-device or
  privacy-preserving and disclosed. (Contrast with the website's legacy UA tag,
  which is deliberately not carried over.)

---

## 16. Content pipeline and release

- `tools/build_db.py` regenerates `gita.sqlite` from `srimad.csv` +
  `data/chapters.toml`; run whenever content changes, commit the built DB into the
  app project (same "build artifact is committed" discipline the site uses for
  `docs/`).
- App and site stay in sync because both derive from `srimad.csv`.
- Standard App Store release: TestFlight beta → phased App Store release for iOS,
  iPadOS, and macOS from the single target.

---

## 17. Phased roadmap

**Phase 0 — Foundations.** Content pipeline (`build_db.py`), bundled `gita.sqlite`
with FTS5, `user.sqlite`, design tokens, app scaffolding, navigation shell for all
three platforms.

**Phase 1 — Read (MVP).** Chapter list, continuous reader with language
visibility, jump-to-verse, bookmarks, reading progress/resume, appearance
settings (theme + font). Ships as a complete offline reading app.

**Phase 2 — Discover.** Full-text search with highlighting/filters, Today screen,
daily verse, widgets, daily notification, share cards.

**Phase 3 — Immersion.** Sanskrit recitation audio and IAST transliteration
(pending §12 content), continuous audio play, lock-screen controls.

**Phase 4 — Sync & polish.** Optional CloudKit sync, Mac keyboard-shortcut pass,
accessibility audit, motion refinement.

---

## 18. Open questions / decisions needed

1. **Audio:** source, licensing, and bundled vs. download-on-demand for ~700
   recitations. (§12)
2. **Transliteration:** generate IAST from the Sanskrit vs. source it; proofing
   plan. (§12)
3. **iCloud sync:** include CloudKit private sync in v1, or defer to Phase 4?
4. **Monetization:** free / free-with-tip / paid — out of scope for this spec but
   affects some later choices.
5. **Fonts:** confirm licensing for the bundled Devanagari and Latin serif faces.
6. **Minimum OS:** confirm iOS/iPadOS/macOS 17/14 floors (drives available APIs).
7. **Attribution:** exact credit/licensing text for the four translation and
   commentary sources and the IIT Kanpur Gita Supersite origin.

---

## Appendix A — Source data reference

Each `srimad.csv` row and content markdown file provides, per verse:

- `chapter` (int), `sutra` (int), `position`/`counter` (global order)
- `mool_shloka` — Sanskrit Devanagari, line breaks preserved
- `hindi` — Hindi translation, Swami Ramsukhdas
- `Commentary` — Hindi commentary, Swami Chinmayananda
- `english_translation` — English translation, Swami Sivananda

Chapter names (Sanskrit + English) come from `data/chapters.toml`, keyed 1–18.
There are 18 chapters and 700 verses total. This is exactly the content the
website renders, ensuring app and web parity from one source of truth.
