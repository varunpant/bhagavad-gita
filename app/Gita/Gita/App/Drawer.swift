//
//  Drawer.swift
//  Gita
//

import Observation
import SwiftUI

/// The left rail's state, shared by the rail and whatever it covers.
///
/// Small enough to be a couple of properties, but it lives in the environment
/// rather than in `ReaderView` because the rail sits outside the reader and both
/// need to agree about it.
@Observable
final class Drawer {
    enum Destination: String, CaseIterable, Equatable {
        case settings, contents, bookmarks, progress

        /// The rail's icon and the noun in its label. Kept beside the case so
        /// the two cannot drift, and so a fifth panel is one line here rather
        /// than six correlated tokens in the container.
        var symbol: String {
            switch self {
            case .settings: "gearshape"
            case .contents: "list.bullet"
            case .bookmarks: "bookmark"
            case .progress: "chart.bar"
            }
        }

        var noun: String { rawValue.capitalized }
    }

    /// Debug builds can launch with the rail already open, for screenshots and
    /// tests, the same way the sheets can.
    /// Search covers everything, rail included, so it lives here rather than
    /// inside the reader.
    var isSearching: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openSearch")
        #else
        false
        #endif
    }()

    /// Set when a search result is chosen; the reader consumes and clears it.
    var requestedVerseID: Int?

    var isOpen: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openMenu")
        #else
        false
        #endif
    }()

    /// A panel shown beside the rail, over the page. Distinct from `destination`
    /// because the rail keeps this one — the reader is not involved.
    var panel: Destination? = {
        #if DEBUG
        {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-openSettingsPanel") || arguments.contains("-openSettings") {
                return .settings
            }
            if arguments.contains("-openContentsPanel") || arguments.contains("-openContents") {
                return .contents
            }
            if arguments.contains("-openBookmarksPanel") { return .bookmarks }
            if arguments.contains("-openProgressPanel") { return .progress }
            return nil
        }()
        #else
        nil
        #endif
    }()

    func open() {
        guard !isOpen else { return }
        isOpen = true
        Haptics.selection()
    }

    func close() {
        guard isOpen || panel != nil else { return }
        isOpen = false
        panel = nil
        Haptics.selection()
    }

    /// Show a panel beside the rail, or put it away if it is already showing.
    func togglePanel(_ destination: Destination) {
        panel = panel == destination ? nil : destination
        Haptics.selection()
    }

    /// Ask the reader to go to a verse, and get out of the way.
    ///
    /// Closing the rail used to be the reader's job, spelled out as two raw
    /// property writes where `close()` already existed. Every route into a
    /// verse — contents, bookmarks, progress, search — wants the same thing, so
    /// it belongs on the one type that owns all of that state.
    func requestVerse(_ verseID: Int) {
        requestedVerseID = verseID
        isOpen = false
        panel = nil
        isSearching = false
    }

    /// Whether anything is on top of the reading surface.
    ///
    /// One question the reader, the dwell tracker and the double-tap gesture
    /// all used to ask by testing the same three properties separately.
    var isCoveringReader: Bool { isOpen || panel != nil || isSearching }

    func search() {
        // The rail stays where it is. Search dims what is behind it rather than
        // dismissing it, so closing search returns to the rail the reader had
        // open rather than to a screen they did not ask for.
        isSearching = true
        Haptics.selection()
    }

}
