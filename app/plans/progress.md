# Progress screen — plan

Reading progress, streaks and badges for Gita, modelled on RigVeda's Progress
feature but sized for a 701-verse book rather than a 7,628-mantra one.

Read alongside `../CLAUDE.md` (how the code is written) and `../specs.md`
(product scope). Reference implementation:
`~/Github/APPS/RigVeda/Swift UI App/RigVeda/RigVeda/{Core/Gamification,Features/Statistics}`.

---

## 1. What RigVeda does, and what Gita should do differently

| RigVeda | Gita | Why |
| --- | --- | --- |
| Mantra counts as read only when you tap **Mark as Read** in a context menu | **Dwell**: landing on a verse and staying 3 seconds counts it | RigVeda's number is honest but almost always zero — nobody finds the menu item. Gita is a deliberate one-verse-at-a-time pager, so presence *is* the signal |
| Streak recorded on **app open** (`recordDailyAppOpen`) | Streak recorded when a verse is actually read | A streak labelled "Day Streak" that only means "you launched the app" doesn't mean what it says |
| `user_stats` singleton table holding 12 pre-aggregated counters, updated by hand on every write | **No aggregate table.** Totals, streaks and completions are derived on read | A hand-maintained cache is a second source of truth that drifts. 701 verses and a few thousand day rows aggregate in microseconds |
| Three tabs: Activity / Metrics / Achievements | **One scrolling column** | Tabs hide two-thirds of the screen behind a control. Gita has one number that matters and enough room to show everything |
| Activity calendar: 12 full months × 5 selectable years | **12-week heatmap** | RigVeda's calendar is an enormous scroll for a book you can finish in a month |
| 48 achievements across 8 categories | **~35 badges across 4 families** | Scaled to the corpus; a badge every 1,000 mantras makes no sense at 701 verses |
| `GamificationService.shared`, `ObservableObject`, `@Published` | `@Observable` + `Environment` | House rule (`CLAUDE.md` § SwiftUI architecture) |
| No way to reset | **Reset progress**, with confirmation | Explicitly requested. Also the thing that makes dwell-tracking safe to ship: if the count feels wrong, you can zero it |

Worth copying as-is: the bilingual badge model (`titleEnglish`/`titleSanskrit`),
the locked-badge-shown-dimmed pattern, and the unlock toast.

---

## 2. Data model

Three new tables in `user.sqlite`, one new append-only migration
`createProgress`. Nothing touches `gita.sqlite`, which stays read-only.

```sql
CREATE TABLE verseReads (
    verseId     INTEGER PRIMARY KEY,        -- Verse.id, 1...701
    firstReadAt DATETIME NOT NULL,
    lastReadAt  DATETIME NOT NULL,
    readCount   INTEGER  NOT NULL DEFAULT 1
);

CREATE TABLE readingDays (
    day        TEXT PRIMARY KEY,            -- "2026-08-16", local calendar
    versesRead INTEGER NOT NULL DEFAULT 0   -- first-time reads only
);

CREATE TABLE badges (
    badgeId    TEXT PRIMARY KEY,
    unlockedAt DATETIME NOT NULL,
    seen       INTEGER NOT NULL DEFAULT 0   -- drives the unlock toast
);
```

Notes that matter:

- **`verseReads` is keyed by verse, not append-only.** Re-reading 2.47 bumps
  `readCount` and `lastReadAt`; it does not create a second row and does not
  advance any total. Only the first insert increments `readingDays.versesRead`.
- **`readingDays.day` is a local-calendar date string**, written at record time
  with `Calendar.current`. Crossing timezones can therefore produce a day that
  is 23 or 25 hours long. That is the correct behaviour for a habit tracker —
  the alternative, UTC days, breaks the streak of anyone who reads at 11pm.
- **No `userStats` table.** See § 1. If aggregation ever shows up in a profile,
  add a cache then, keyed by a content version, not before.

## 3. What counts as read

`ReadingTracker` — `@Observable`, owned by `RootView`, injected via
`Environment`.

```
on currentVerseID change:
    cancel any pending dwell task
    guard scenePhase == .active
    guard !drawer.isOpen && drawer.panel == nil && !drawer.isSearching
    Task {
        try await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled
        await progress.record(verseID)       // off the main actor
    }
```

Four guards, each earning its place:

- **Cancellation on change** is what makes fast swiping not count. Flicking
  through thirty verses to reach 12.13 records nothing.
- **`scenePhase == .active`** stops a verse left on screen overnight from
  counting when the phone is picked up.
- **The drawer guard** stops the verse behind an open panel from counting while
  you browse the contents.
- **`Task.sleep` is cancellable and structured** — no timers to invalidate, no
  `Task.detached`.

3 seconds is a guess. It should be a constant in one place so it can be tuned
after living with it.

## 4. Derived values

All computed from the two tables, no cache:

| Value | Derivation |
| --- | --- |
| Verses read | `SELECT COUNT(*) FROM verseReads` |
| Overall completion | read / **701** — read the denominator from `chapters`, never hardcode 700 (the corpus has 701 rows; 13.1 is split in the source) |
| Per-chapter completion | join `verseReads` against the verse's chapter, over `Chapter.verseCount` |
| Days read | `SELECT COUNT(*) FROM readingDays` |
| Current streak | walk back from **today, or yesterday if nothing has been read today yet**, counting consecutive days |
| Longest streak | longest run in the sorted day list |

The "or yesterday" clause is the one piece of real logic here: without it the
streak reads as broken from midnight until you next open the app, which is
exactly when someone checks it and gets discouraged.

`Streak.current(from:today:)` and `Streak.longest(from:)` are **`nonisolated`
pure functions over `[String]`**, with `today` injected. That makes every streak
edge case a unit test with no database, no clock and no running app.

## 5. Badges

`Badge` is a value type; `BadgeCatalog.all` is a static array. The whole system
reduces to one pure function:

```swift
nonisolated struct ProgressSnapshot: Sendable {
    let readVerseIDs: Set<Int>
    let versesReadPerChapter: [Int: Int]
    let currentStreak: Int
    let longestStreak: Int
    let daysRead: Int
}

nonisolated static func unlocked(for snapshot: ProgressSnapshot) -> Set<Badge.ID>
```

Everything else — the database, the toast, the grid — is plumbing around that
function. It is the single most testable seam in the feature, and it is why
badges need no integration test.

Four families, 35 badges, bilingual titles (`titleSa` / `titleEn`) since the
reader has a language toggle:

**Verse milestones (7)** — 1, 10, 50, 100, 250, 500, 701.
Named from the Gita's own vocabulary: प्रथम पद (First Step), जिज्ञासु (The
Enquirer), साधक (The Practitioner), स्थितप्रज्ञ (Steady in Wisdom) …, ending at
गीता पूर्ण (Gita Complete) for all 701.

**Chapter completion (18)** — one per chapter, named for that chapter's yoga:
अर्जुनविषादयोग, सांख्ययोग, कर्मयोग … मोक्षसंन्यासयोग. This family maps onto how
the Gita is actually read, and it is the one that will unlock most often.

**Daily streaks (4)** — 7, 30, 100, 365 consecutive days:
सप्ताह (Week), मास (Month), शतक (Hundred), संवत्सर (Year).

**Landmark verses (6)** — reaching famous shlokas, unlocked by verse ID rather
than by count: 2.20 (the imperishable self), 2.47 (कर्मण्येवाधिकारस्ते),
4.7 (यदा यदा हि धर्मस्य), 9.22 (योगक्षेमं वहाम्यहम्), 11.32 (कालोऽस्मि),
18.66 (सर्वधर्मान्परित्यज्य). Small, specific to this text, and the family most
likely to make someone smile.

Two invariants worth testing explicitly: **no badge unlocks on an empty
snapshot**, and **unlocking is monotonic** — adding progress can never remove a
badge. The second is what catches a requirement accidentally written as `==`.

## 6. The screen

A panel sliding in from the left over the content with the cross at the rail —
identical in behaviour to Contents, Settings and Bookmarks. Entry point is a
**seventh rail icon** (`chart.bar`), between bookmark and the language toggle.

One scrolling column, top to bottom:

```
┌─────────────────────────────────────────┐
│  ✕                              Progress │
│                                          │
│              ╭─────────╮                 │   1. Completion ring
│             │    18%    │                │      127 of 701 read
│              ╰─────────╯                 │
│            127 / 701 शلोक                │
│                                          │
│   127          6           23            │   2. Three figures
│   read       streak      days            │
│                                          │
│  ─── Chapters ───────────────────────    │   3. 18 chapter bars
│  १  अर्जुनविषादयोग      ████████░░ 47/47 │      tap to jump there
│  २  सांख्ययोग           ███░░░░░░░ 22/72 │
│  …                                       │
│                                          │
│  ─── Last 12 weeks ─────────────────     │   4. Heatmap
│  ▪▪▫▪▪▪▫ ▪▫▫▪▪▪▪ ▫▫▪▪▪▪▪ …              │
│                                          │
│  ─── Badges ──────────────── 9 of 35 ──  │   5. Badge grid
│  ◉ प्रथम पद   ◉ जिज्ञासु   ○ साधक        │      locked ones dimmed
│  ◉ कर्मयोग    ○ सांख्ययोग  ○ …           │
│                                          │
│                                          │
│           Reset progress                 │   6. Destructive, last
└─────────────────────────────────────────┘
```

**The chapter list is the part worth getting right.** It is the only view in the
app that shows the Gita as a whole with your place in it, and tapping a chapter
should move the reader there — which makes Progress a navigation surface, not
just a trophy cabinet.

**Theme.** Everything obeys the existing rule: white background, black text,
grey rules in System/Light; sepia only under Sepia. The ring and the filled
heatmap cells use `theme.accent` (which is `.primary` outside sepia) — **not**
`Brand.gradient`. The rail and the splash are the two deliberate brand
exceptions; a gradient ring would put orange back on a light-theme screen,
which is the thing that has gone wrong twice already.

**Naming.** The view cannot be called `ProgressView` — that is a SwiftUI type.
`ReadingProgressView`.

## 7. Reset

At the bottom of the panel, below everything, so it takes a deliberate scroll to
reach. Plain destructive text, not a filled button.

Tapping opens a `confirmationDialog` that names **exactly what goes and what
stays**:

> **Reset progress?**
> This erases 127 verses read, a 6-day streak and 9 badges.
> Your bookmarks and settings are not affected.
> [Reset progress] [Cancel]

Naming what survives matters more than naming what goes — people conflate
bookmarks with progress, and the fear of losing 40 saved verses is what stops
them using the feature at all.

Implementation: one transaction deleting from `verseReads`, `readingDays` and
`badges`. It does not drop or re-run migrations, and it does not touch
`settings` or `bookmarks`. A unit test asserts precisely that.

## 8. Files

```
Core/Progress/
  ReadingProgress.swift          @Observable — owns the read set, exposes the snapshot
  ProgressSnapshot.swift         nonisolated Sendable struct — pure badge input
  ReadingTracker.swift           the dwell timer
  Streak.swift                   nonisolated pure functions over [String]
  Badge.swift                    model + Requirement enum
  BadgeCatalog.swift             the 35 badges
Core/Database/
  UserDatabase+Progress.swift    migration, queries, reset
Features/Progress/
  ReadingProgressView.swift      the panel
  Components/CompletionRing.swift
  Components/ChapterProgressList.swift
  Components/ActivityHeatmap.swift
  Components/BadgeGrid.swift
  Components/BadgeUnlockToast.swift
```

Touched: `App/Drawer.swift` (a `.progress` destination), `App/DrawerContainer.swift`
(the seventh icon), `App/RootView.swift` (inject `ReadingProgress`, mount the
tracker), `Core/Database/UserDatabase.swift` (register the migration).

## 9. Testing

Unit tests only — the design above exists to make that possible.

| Suite | Covers |
| --- | --- |
| `StreakTests` | empty, one day, unbroken run, gap, read-today vs read-yesterday, longest ≠ current, a run spanning a month boundary |
| `BadgeTests` | table-driven over snapshots; every badge reachable; nothing unlocks at zero; monotonicity |
| `ProgressMathTests` | 701 denominator, per-chapter counts sum to the total, chapter completion at exactly `verseCount` |
| `ProgressStoreTests` | migration applies; recording twice does not double-count; `readingDays` increments only on first read; reset clears the three tables and leaves bookmarks and settings intact |

One UI test — the panel opens from the rail and reset empties it — and per
`CLAUDE.md`, **ask before running it**.

The dwell timer is the one piece that resists unit testing. Keep the *policy*
(should this verse count, given scene phase and drawer state?) as a pure
function and test that; leave only the `Task.sleep` untested.

## 10. Phases

1. **Data and tracking, no UI.** Migration, `ReadingProgress`, `ReadingTracker`,
   `Streak`, snapshot. All four unit suites green. Nothing visible in the app —
   progress starts accumulating silently, which means the feature has real data
   in it the day the screen lands.
2. **The screen.** Rail icon, panel, ring, three figures, chapter list.
3. **Heatmap and badges.** `BadgeCatalog`, grid, unlock toast.
4. **Reset.**

Phase 1 is the one with the risk in it; 2–4 are presentation over a settled
model.

## 11. Open questions

- **Is 3 seconds the right dwell?** Only living with it will say. One constant.
- **Should the widget show progress?** `SharedVerses` already writes to the App
  Group, so a "142 of 701" widget is cheap later. Out of scope here.
- **Should reading a verse in English and in Sanskrit count twice?** Proposed:
  no. The verse is the unit, not the rendering.
