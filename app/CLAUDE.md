# CLAUDE.md — Gita app

Native SwiftUI reading app for all 700 verses of the Bhagavad Gita. Companion to
the Hugo site in the repository root (`bhagwadgita.info`), sharing one source of
truth: `../srimad.csv` + `../data/chapters.toml`.

**Read `specs.md` (this directory) before making product decisions.** It is the
authority on scope, screens, design tokens, and the phased roadmap. This file is
the authority on *how the code is written*.

**Sibling reference:** `~/Github/APPS/RigVeda/Swift UI App/RigVeda` — the same kind
of app (bundled scripture DB, Devanagari typography, bookmarks, widgets, share
cards), already shipped. Read it for structure and for solved problems. §"Learning
from RigVeda" below says what to copy and what to deliberately do differently.

## Layout

Current state — bare Xcode Multiplatform template, builds clean, nothing else:

```
app/
  specs.md                  product spec — read first
  CLAUDE.md                 this file
  Gita/
    Gita.xcodeproj
    Gita/{GitaApp,ContentView}.swift, Assets.xcassets
    GitaTests/  GitaUITests/
```

Target structure, borrowed from RigVeda and grown into as Phase 0→2 land
(`specs.md` §17):

```
Gita/Gita/
  App/
    GitaApp.swift            @main, scene graph, environment wiring
    RootView.swift           TabView (iPhone) / NavigationSplitView (iPad, Mac)
    Route.swift              Hashable + Codable navigation values
  Core/
    Database/
      ContentDatabase.swift  gita.sqlite — bundled, read-only
      UserDatabase.swift     user.sqlite — App Group, migrated
      Models/                Verse, Chapter, Bookmark, ReadingPosition — Sendable structs
    Search/                  FTS5 queries, snippet highlighting, debounce
    Design/
      Theme.swift            semantic tokens + Sepia theme
      Color+Tokens.swift     asset-catalog-backed token accessors
      Font+Roles.swift       .shloka / .translation / .commentary / .label
    Widget/                  shared data provider for WidgetKit
    AppIntents/              VerseEntity, OpenVerseIntent, shortcuts
    Utilities/               Constants, Logger+Extensions, Haptics, ShareCard
    Components/              small reusable views used by 2+ features
  Features/
    Today/  Read/  Reader/  Search/  Bookmarks/  Settings/
      <Feature>View.swift
      <Feature>Model.swift  @Observable, only when there's real state to own
      Components/           views used only by this feature
  Resources/
    Database/gita.sqlite     committed build artifact
    Fonts/                   bundled Devanagari + serif faces
```

Group **by feature, not by layer** — `Features/Reader/` holds its view, its model,
and its subviews together. RigVeda's `Views/` + `ViewModels/` subfolders inside
each feature are the one bit of its layout not worth copying; at this size they
just add a hop.

Xcode 16+ synchronized filesystem groups (`objectVersion = 77`, which this project
uses) mean dropping a file into a folder adds it to the target. No `project.pbxproj`
edits, no merge conflicts in it.

## Required project configuration

The wizard defaults do **not** match the spec. Target state:

| Setting | Required | Why |
| --- | --- | --- |
| Supported Destinations | iPhone, iPad, **Mac** (native — not "Mac (Designed for iPad)") | §3: one universal target, genuinely native on Mac |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | §3 |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` | §3 |
| `SWIFT_VERSION` | `6.0` (Swift 6 language mode) | Data-race safety enforced at compile time |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Single-threaded by default; see Concurrency |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | ditto |
| App Group | `group.<bundle-id>` | §10/§11: widgets read progress + daily verse |
| `PRODUCT_BUNDLE_IDENTIFIER` | pick once, never change | Ships to the App Store; App Group and CloudKit derive from it |

Add the App Group **before** writing any persistence code. `user.sqlite` must be
created in the group container from the first line. RigVeda's `DatabaseService`
carries a permanent Documents→App Group migration block precisely because that
decision came second — don't inherit that debt.

## Concurrency — Swift 6, approachable mode

Toolchain is Swift 6.3. With approachable concurrency and `MainActor` default
isolation, **unannotated code is main-actor and single-threaded.** You don't
sprinkle `@MainActor`; you mark the few things that leave the main actor.

- Views, `@Observable` models, navigation state: leave unannotated.
- Off-main work: `nonisolated` functions or an `actor`. `@concurrent` when a
  `nonisolated async` function should actually hop to the concurrent pool.
- Never `Task { @MainActor in … }` to silence a warning, never
  `@unchecked Sendable`. An isolation-crossing error means a mutable class is
  being shared — fix the design.
- Structured concurrency only: `async let`, `TaskGroup`, `.task(id:)`.
  `Task.detached` (as in RigVeda's `init`) escapes cancellation and structure —
  use `.task` on the root view for startup warm-up instead.
- Models crossing the DB boundary are `Sendable` structs. RigVeda's
  `struct Mantra: Identifiable, Codable, Equatable, Sendable` is exactly right;
  copy that shape for `Verse` and `Chapter`.

## SwiftUI architecture

**Observation, not ObservableObject.** `@Observable` final classes held with
`@State` where owned, passed via `Environment` where shared.
`ObservableObject` / `@Published` / `@StateObject` are legacy — RigVeda uses them
throughout (`SettingsManager`, `ReadingViewModel`); do not carry that over. `@Observable`
also fixes the real problem in that code: a view depending on one `@Published`
property re-renders on every change to any of the ~20, whereas Observation tracks
per-property reads.

**No singletons for app state.** RigVeda leans on `.shared` everywhere
(`DatabaseService`, `SettingsManager`, `GamificationService`). Inject instead:

```swift
@main struct GitaApp: App {
    @State private var library = Library()      // content DB, read-only
    @State private var settings = Settings()    // user DB
    var body: some Scene {
        WindowGroup { RootView() }
            .environment(library)
            .environment(settings)
    }
}
```

That's what makes previews and tests possible without a live database.

**No ViewModel per View.** SwiftUI views *are* the view layer; a
`FooView` + `FooViewModel` pair that only forwards properties is noise. Reach for
an `@Observable` model when a feature owns genuine cross-view state (reader
position, search query + debounce, settings) — otherwise plain views with `@State`.
Sheet-presentation booleans belong in `@State` on the view, not in the model
(RigVeda's `ReadingViewModel` holds five of them).

**Navigation is value-based.** `NavigationStack(path:)` on iPhone,
`NavigationSplitView` on iPad/Mac (§6, §13). `Route` is `Hashable` + `Codable` so
state restoration and widget deep links (§11) resolve through the same type. Never
`NotificationCenter` for navigation (RigVeda's `.navigateToLastPosition`) — it's
untyped, untestable, and invisible to the compiler.

**The reader is the performance-critical screen** (§7.3): `ScrollView` +
`LazyVStack`, `.scrollPosition(id:)` for the last-read anchor,
`.scrollTargetLayout()` where snapping is wanted. Verse leaves must be cheap — no
attributed-string building or date formatting inside `body`. Precompute on load.

**Modern layout primitives:** `Grid`, `ViewThatFits`, `containerRelativeFrame`,
`.safeAreaInset` for the progress rail, `@Entry` for custom environment keys.
`GeometryReader` is a last resort — it breaks sizing and defeats laziness.

## Data layer

Two databases, per §4.2 — the split is not optional:

- `gita.sqlite` — bundled, **read-only**, built by `../tools/build_db.py` from
  `srimad.csv`. Open straight from the bundle with
  `Configuration(readonly: true)`. **Do not copy it into the container** the way
  RigVeda does; that was needed there because the DB is written to, and it doubles
  disk use and adds a first-launch stall.
- `user.sqlite` — writable, in the App Group container, versioned with GRDB's
  `DatabaseMigrator`. Migrations are registered once and are append-only forever.

Use **GRDB**, not the raw `sqlite3` C API. RigVeda's hand-rolled
`OpaquePointer` + `sqlite3_prepare_v2` layer works but hand-writes statement
finalization, column decoding, and error mapping for every query — GRDB gives
record mapping, migrations, and `ValueObservation` for free with the same actor
safety.

Rules:

- All SQL lives in the `Core/Database` layer. GRDB types (`Row`, `Database`) never
  escape it; map to `Sendable` structs at the boundary. Views never see GRDB.
- Observe with `ValueObservation` bridged to an `AsyncSequence`, consumed in
  `.task { }`. Never poll, never re-query in `body`.
- Search: FTS5 with `snippet()` for highlighting (§7.4). `.task(id: query)` gives
  you debounce and cancellation of the in-flight query in one move.
- `chapter` / `sutra` are integers, exactly as on the site side. The root
  `CLAUDE.md` documents what breaks when that slips.

## Design system

Implement §9 as **semantic tokens, never raw hex at the point of use.** Follow
RigVeda's asset-catalog approach — one colorset per token, light/dark variants
inside it, surfaced through a `Color` extension — for `background`, `surface`,
`textPrimary`, `textSecondary`, `accent`, `divider`. Name them by role
(`Color.textSecondary`), not by hue; RigVeda's `VedicBrown` / `VedicYellow` sets
are the trap to avoid.

Sepia is a fourth theme, so it can't ride on `ColorScheme` alone: carry the choice
in `Settings` and resolve tokens through the environment.

Typography: a `Font` extension exposing **roles** — `.shloka`, `.translation`,
`.commentary`, `.label` — each built with `.custom(_:size:relativeTo:)`.
RigVeda's `Font+Extensions` names faces (`kohinoorRegular(_:)`) and uses
`.system(size:)`, which pins sizes and ignores Dynamic Type. Roles + `relativeTo:`
keep §14's Dynamic Type promise while the in-app slider layers on top.

Śloka line breaks are semantic (§8): `.lineLimit(nil)`, no whitespace
normalization that collapses newlines.

Copy `Constants.swift` and `Logger+Extensions.swift` wholesale in spirit — a
namespaced `enum Constants` for app/DB/UI values and per-category `Logger`s
(`Logger.ui`, `Logger.database`) instead of `print`.

## Accessibility (§14)

Written as you go, not as a final pass:

- Each verse leaf: one `.accessibilityElement(children: .contain)` with labeled
  children, so VoiceOver reads "Chapter 2, verse 47, Sanskrit…".
- `.accessibilityLanguage()` on Devanagari and Hindi text so the right voice reads it.
- Honor `\.accessibilityReduceMotion` around every animation and
  `\.accessibilityReduceTransparency` around materials.
- AA contrast in all four themes — check saffron against each background.

## Testing

Swift Testing (`@Test`, `#expect`, `#require`) for new tests; suites are `struct`s;
`@Test(arguments:)` for table-driven cases. XCTest only where XCUITest requires it.

Test what's worth testing: the built DB (700 verses, 18 chapters, FTS returns
expected hits), daily-verse determinism (same date → same verse on every
platform), repository queries against a fixture DB, share-card text formatting. No
snapshot tests of SwiftUI `body`.

## Build and verify

```bash
cd app/Gita
xcodebuild -scheme Gita -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme Gita -destination 'platform=macOS' build
xcodebuild -scheme Gita -destination 'platform=macOS' test
```

**Always build both destinations.** A `UIKit` import or an iOS-only modifier
compiles for iOS and breaks Mac silently until someone builds it — RigVeda is
iOS-only and imports `UIApplication` freely; that code cannot be lifted across
without adaptation. Wrap platform differences in `#if os(macOS)` at the smallest
possible scope, and prefer a cross-platform API over a fork.

## Learning from RigVeda

| Copy | Do differently |
| --- | --- |
| `Core/` + `Features/` top-level split | drop the per-feature `Views/`+`ViewModels/` subfolders |
| `Sendable` struct models with computed `reference` | — |
| Asset-catalog color tokens via a `Color` extension | name tokens by role, not by hue |
| Namespaced `enum Constants` | — |
| Per-category `OSLog` `Logger`s | — |
| App Group container for shared/widget data | set it up first, so no migration is ever needed |
| `AppIntents` entity + open intent for Shortcuts/widgets | — |
| On-device share-card image generation | — |
| DB access serialized behind an actor | GRDB, not the raw `sqlite3` C API |
| — | `@Observable` + `Environment`, not `ObservableObject` + `.shared` |
| — | typed `Route` values, not `NotificationCenter` navigation |
| — | read `gita.sqlite` in place from the bundle, don't copy it out |
| — | universal (iPhone/iPad/Mac), not iOS-only |

RigVeda also has `design/` (App Store screenshot pipeline with Playwright, splash,
store templates) and `scripts/`. When Gita reaches release prep, look there first
rather than reinventing it.

## Gotchas

- Xcode's Multiplatform template is the only thing that gives one target three
  destinations. "Mac (Designed for iPad)" is the iPad app in a window — not what
  §3 asks for, and it locks out Mac-only APIs (menu bar, `Settings` scene,
  multiple windows).
- `xcuserdata/` and `UserInterfaceState.xcuserstate` are per-user Xcode state.
  Gitignore them; they churn on every Xcode launch and conflict constantly.
  Shared schemes (`xcshareddata/xcschemes/`) *do* belong in git — RigVeda gets
  this right.
- The built `gita.sqlite` **is committed**, matching the site's discipline of
  committing `docs/` (§16). Regenerate only via `tools/build_db.py`; hand-edits
  aren't durable, exactly as with `content/` on the site side.
- Do not add SwiftData. Bundled-read-only content + separate writable user store
  is what GRDB is here for, and two persistence stacks in one app is a permanent tax.
- Audio (`verses.audio_file`) and IAST transliteration are **content
  dependencies**, not code gaps (§12). Degrade gracefully on null; never stub fake
  data.
- The website's Google Analytics tag is deliberately not carried over (§15). No
  third-party analytics, no tracking SDKs.
