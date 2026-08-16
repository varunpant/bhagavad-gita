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
| App Group | `group.com.varunpant.Gita`, via `Gita.entitlements` | §10/§11: widgets read progress + daily verse |
| `PRODUCT_BUNDLE_IDENTIFIER` | pick once, never change | Ships to the App Store; App Group and CloudKit derive from it |

The App Group is configured: `Gita.entitlements` sits **beside** the synchronized
source folder, not inside it, so Xcode's filesystem groups cannot sweep it into
the bundle as a resource. `UserDatabase` prefers the group container and falls
back to Application Support, so it kept working before the entitlement existed
and keeps working in contexts without it (previews, some test hosts).

A widget target added later needs the same entitlement and the same group id, and
must be code-signed by the same team.

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

Śloka line breaks are semantic (§8) — but only **11 of the 701** rows in
`srimad.csv` actually contain newlines. In the other 690 the danda (`।`) is the
only break available, so `Verse.lines` honours real newlines where they exist and
falls back to breaking on the danda, keeping the trailing `।।chapter.verse।।`
marker attached to the final line. `VerseTests` checks that this is lossless
across the whole corpus. If the CSV is ever repaired to carry real line breaks,
the fallback simply stops being used.

Copy `Constants.swift` and `Logger+Extensions.swift` wholesale in spirit — a
namespaced `enum Constants` for app/DB/UI values and per-category `Logger`s
(`Logger.ui`, `Logger.database`) instead of `print`.

## Accessibility (§14)

Written as you go, not as a final pass:

- Each verse leaf: one `.accessibilityElement(children: .contain)` with labeled
  children, so VoiceOver reads "Chapter 2, verse 47, Sanskrit…".
- Tag Devanagari and Hindi for VoiceOver by setting `languageIdentifier` on an
  `AttributedString` and passing that to `.accessibilityLabel`/`.accessibilityValue`.
  SwiftUI has **no** `.accessibilityLanguage` view modifier — the language rides
  on the string, not on the view.
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

## Search

Two layers, deliberately separate:

- **Full-text (FTS5)** over Sanskrit, transliteration, both translations and both
  meanings. Instant, offline, exact. This is what answers "krishna", "2.47",
  "कर्म". Query text is sanitised by `ContentDatabase.sanitize` before it reaches
  FTS5 — see `SearchSafetyTests` for what that guards and why.
- **Semantic (`SemanticIndex`)** over the English translation and meaning, using
  Apple's `NLContextualEmbedding`. Adds nothing to the app download; the vectors
  are built on device once and cached, keyed by `content_version`.

Full-text results always lead; semantic ones appear under "Related". Three
things about the embeddings that are easy to get wrong, all measured:

- **Never use an absolute similarity threshold.** Mean-pooled contextual
  embeddings sit in a narrow band — every verse scores 0.85–0.92 against any
  English query. Selection is relative to the best score.
- **Centre the vectors.** Subtracting the corpus mean (from the query too) is
  what stops a handful of hub verses winning every query. It widens the top-50
  spread from ~0.03 to ~0.2.
- **They are thematically good, not precise.** A paraphrase of 2.20 retrieves
  2.20 first; a query phrased almost exactly like 2.47 ranks it 59th of 701.
  Do not build a feature that assumes exact retrieval.

Anything to do with the OS embedding asset must be **bounded**. The
`requestAssets` callback never fires in the simulator, and an unbounded await
hangs forever instead of degrading. Semantic search is optional everywhere: if
it is unavailable, search stays literal and nothing is shown to the reader.

## Widgets

A widget runs in its own process, cannot read the app's bundle, and **cannot ask
the app for anything** — when a timeline refreshes the app is usually not
running. Data only ever flows app → shared container.

So the app exports the corpus once into the App Group as `widget-verses.json`
(~680 KB, keyed by `content_version`), and the widget reads it there. The whole
corpus rather than just today's verse: `DailyVerse` is a pure function of the
date, so the widget works out any day by itself and can never go stale, however
long since the app was opened. Before the first launch there is nothing to read,
and the widget says so plainly rather than showing an error.

Two constraints that shaped the target:

- **Anything the widget compiles must not touch `Verse`**, which imports GRDB.
  `DailyVerse` and `SharedVerses` are split so the shared halves are pure — the
  `Verse` conveniences live in `+Verse` / `+Export` files that only the app
  builds.
- **Nothing may sit inside a synchronized source folder that also gets copied as
  a resource.** `Info.plist` and `.entitlements` files live beside those folders,
  not in them, or the build fails with "multiple commands produce Info.plist".

Deep links are `gita://verse/<chapter>/<sutra>`. The scheme needs
`CFBundleURLTypes`, which has no `INFOPLIST_KEY` equivalent, so the app supplies
`Gita-Info.plist`. A cold launch from a widget arrives before the corpus is in
memory, so the request is held and applied once it loads.

## Build and verify

**Do not run the UI tests without asking first.** `GitaUITests` launches the app
for every test — a full run is minutes long and blocks whoever is watching.
Verify with a build, then the unit tests (`-only-testing:GitaTests`, well under a
second), and only run a UI suite when it is the thing actually in question — and
ask before you do. Prefer moving behaviour into pure functions on the models so
it can be tested without a running app at all.

**Never run a command that produces no console output** — a silent `xcodebuild`
is indistinguishable from a hung one, and `timeout` does not exist on macOS
(prefixing with it means the command never runs at all). Run the suite *before*
committing, not chained to the commit.

Semantic-search tests need the OS embedding asset, which the simulator does not
provide — run them on macOS. They skip cleanly elsewhere.

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
