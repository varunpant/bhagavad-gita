//
//  DailyVerse.swift
//  Gita
//

import Foundation

/// Which verse belongs to a given day.
///
/// Deterministic from the date alone (specs.md §11) so the app, the notification
/// and — once it exists — the widget always name the same verse without needing
/// to agree at runtime or store anything.
///
/// A plain seeded shuffle rather than `dayOfYear % count`: the modulo walks the
/// corpus in order, so a reader would get 1.1, 1.2, 1.3 on consecutive days and
/// never reach chapter 18 in a year.
///
/// The guarantee is per **cycle**: within each aligned run of `count` days every
/// verse appears exactly once. Each cycle draws a fresh permutation, so a window
/// straddling a boundary can repeat one verse while missing another — 701 days
/// is nearly two years, and the alternative is carrying state.
nonisolated enum DailyVerse {
    /// Index into an ordered corpus of `count` verses, for the day containing
    /// `date` in the given calendar.
    static func index(for date: Date, count: Int, calendar: Calendar = .current) -> Int {
        guard count > 0 else { return 0 }

        let day = calendar.startOfDay(for: date)
        let daysSinceEpoch = Int((day.timeIntervalSince1970 / 86_400).rounded(.down))

        // Which pass through the corpus, and how far into it.
        let cycle = Int((Double(daysSinceEpoch) / Double(count)).rounded(.down))
        let offset = daysSinceEpoch - cycle * count

        // A fresh permutation per cycle, so the second pass is not the first
        // pass again in the same order.
        return shuffled(count: count, seed: UInt64(bitPattern: Int64(cycle)))[offset]
    }

    /// Fisher-Yates driven by a seeded generator, so the order is identical on
    /// every device and every platform for the same seed.
    private static func shuffled(count: Int, seed: UInt64) -> [Int] {
        var generator = SplitMix64(seed: seed &* 0x9E37_79B9_7F4A_7C15)
        var order = Array(0 ..< count)
        for index in stride(from: count - 1, to: 0, by: -1) {
            let swap = Int(generator.next() % UInt64(index + 1))
            order.swapAt(index, swap)
        }
        return order
    }
}

/// A small, fast, fully specified PRNG. `SystemRandomNumberGenerator` cannot be
/// seeded, and `Int.random` gives no reproducibility guarantee across releases —
/// both of which would break the promise that every surface picks the same verse.
private nonisolated struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
