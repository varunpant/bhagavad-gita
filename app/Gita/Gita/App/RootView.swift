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
    @Environment(\.theme) private var theme

    @State private var showingSplash = !ProcessInfo.processInfo.arguments.contains("-skipSplash")

    /// Long enough to register as a title page rather than a flash, short enough
    /// not to be in the way. The corpus usually loads well inside this.
    private let minimumDuration = Duration.milliseconds(750)
    /// Never hold the reader back if loading stalls — the reader shows its own
    /// state for that.
    private let patience = Duration.seconds(3)

    var body: some View {
        ZStack {
            ReaderView()

            if showingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
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
