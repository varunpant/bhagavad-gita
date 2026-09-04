//
//  RootView.swift
//  Gita
//

import SwiftUI

/// Holds the splash over the reader until the text is ready.
///
/// The reader is built underneath the whole time rather than after, so loading
/// happens behind the splash instead of being started by its disappearance.
struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Drawer.self) private var drawer
    @Environment(Settings.self) private var settings
    @Environment(ReadingProgress.self) private var progress
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    @State private var showingSplash = !ProcessInfo.processInfo.arguments.contains("-skipSplash")

    /// Shown once, on a first launch — and afterwards only from Settings, where
    /// the same six pages serve as the guide.
    @State private var showsWelcome = false

    /// Long enough for the ground to finish resolving from soft to sharp — the
    /// splash animation is two seconds, and cutting away mid-focus would look
    /// like a glitch rather than a transition.
    private let minimumDuration = Duration.milliseconds(2_050)
    /// Never hold the reader back if loading stalls — the reader shows its own
    /// state for that.
    private let patience = Duration.seconds(3)

    var body: some View {
        ZStack {
            DrawerContainer { ReaderView() }

            if drawer.isSearching {
                SearchOverlay(
                    onSelect: { drawer.requestVerse($0.id) },
                    onDismiss: { drawer.isSearching = false }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                .zIndex(2)
            }

            // Earning something silently is the same as not earning it. One
            // line, at the top, gone on its own — deliberately not a sheet or
            // a card, which would interrupt the reading this is rewarding.
            if let earned = progress.newlyEarned.first {
                // Behind the toast, over everything else. Seeded from the badge
                // so the same goal falls the same way twice.
                Confetti(seed: earned.id.hashValue)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2.5)

                BadgeToast(badge: earned)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(3)
            }

            if showingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            // After the splash, not instead of it: the app opens on the brand
            // ramp either way, and the welcome carries the same surface on.
            if showsWelcome, !showingSplash {
                WelcomeView { withAnimation(.easeOut(duration: 0.3)) { showsWelcome = false } }
                    .transition(.opacity)
                    .zIndex(4)
            }
        }
        // No clock, no battery, no carrier — on every screen, not just the
        // guide. The reading surface is the whole page, and the one piece of
        // furniture the app cannot style is the one it does not own.
        //
        // Belt and braces, and the braces are in `Gita-Info.plist`:
        // `UIViewControllerBasedStatusBarAppearance` is NO there, which takes
        // the decision away from the hosting controller altogether. This line
        // is the belt — a preference, which is all SwiftUI can express, and
        // which is why it was not enough on its own.
        //
        // A Mac has no status bar to hide, and the modifier is not merely a
        // no-op there — it is `unavailable`, so the smallest possible `#if`
        // rather than a cross-platform call, which is the rule the rest of
        // this target follows.
        #if os(iOS)
        .statusBarHidden(true)
        #endif
        .task { showsWelcome = !settings.hasSeenWelcome }
        .publishesProgressToWidgets()
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: drawer.isSearching)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: progress.newlyEarned.first)
        // Keyed on the badge, so a second one earned while the first is up gets
        // its own four seconds rather than inheriting what is left of them.
        .task(id: progress.newlyEarned.first) {
            guard progress.newlyEarned.first != nil else { return }
            // The firmest feedback in the app, for the rarest event in it.
            Haptics.celebrate()
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, !progress.newlyEarned.isEmpty else { return }
            progress.newlyEarned.removeFirst()
        }
        // The reminder is scheduled a fortnight ahead, so it has to be topped up
        // by the app itself: `DailyReminder.schedule` was only ever called from
        // the switch in Settings, which meant a reader who turned it on and then
        // simply read for a fortnight stopped being reminded, permanently, with
        // nothing to tell them why. Refilling the window on every launch is what
        // the horizon was always for.
        .task(id: library.state.isReady) {
            guard library.state.isReady, settings.dailyReminder else { return }
            // Refill rather than schedule: on launch the app must never be the
            // thing that asks for permission — see `refillIfAuthorized`.
            await DailyReminder.refillIfAuthorized(
                at: settings.reminderTime, verses: library.verses
            )
        }
        .task {
            guard showingSplash else { return }
            let start = ContinuousClock.now

            try? await Task.sleep(for: minimumDuration)
            while !library.state.isReady, ContinuousClock.now - start < patience {
                try? await Task.sleep(for: .milliseconds(40))
            }

            // The feedback is the handover: the app has opened, start reading.
            Haptics.pageTurn()
            withAnimation(.easeOut(duration: 0.35)) { showingSplash = false }
        }
    }
}
