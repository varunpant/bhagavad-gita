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
    enum Destination: Equatable {
        case settings
        case contents
        case search
    }

    /// Debug builds can launch with the rail already open, for screenshots and
    /// tests, the same way the sheets can.
    var isOpen: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openMenu")
        #else
        false
        #endif
    }()

    /// Set by a rail icon; the reader picks it up, presents, and clears it.
    var destination: Destination?

    func open() {
        guard !isOpen else { return }
        isOpen = true
        Haptics.selection()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        Haptics.selection()
    }

    func choose(_ destination: Destination) {
        self.destination = destination
        isOpen = false
        Haptics.selection()
    }
}
