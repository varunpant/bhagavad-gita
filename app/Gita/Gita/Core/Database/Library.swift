//
//  Library.swift
//  Gita
//

import Foundation
import Observation
import OSLog

/// The Gita's text, loaded once and shared through the environment.
///
/// Main-actor by default (the target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor`); the database read itself happens off the main actor and only
/// `Sendable` values cross back.
@Observable
final class Library {
    enum State {
        case loading
        case ready
        case failed(String)

        var isReady: Bool { if case .ready = self { true } else { false } }
    }

    private(set) var verses: [Verse] = []
    private(set) var chapters: [Chapter] = []
    private(set) var contentVersion = "0"
    private(set) var state: State = .loading

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "Library"
    )

    func load() async {
        guard case .loading = state else { return }
        do {
            let loaded = try await Self.fetchAll()
            verses = loaded.verses
            chapters = loaded.chapters
            contentVersion = loaded.version
            state = .ready
            Self.logger.info("Loaded \(self.verses.count) verses")
        } catch {
            state = .failed(error.localizedDescription)
            Self.logger.error("Failed to load verses: \(error.localizedDescription)")
        }
    }

    @concurrent
    private static func fetchAll() async throws -> (verses: [Verse], chapters: [Chapter], version: String) {
        let database = try ContentDatabase()
        return (try database.allVerses(),
                try database.allChapters(),
                try database.contentVersion() ?? "0")
    }

    /// Full-text search, off the main actor.
    @concurrent
    static func search(_ query: String) async throws -> [SearchHit] {
        try ContentDatabase().search(query)
    }

    /// Verses of one chapter, in order.
    func verses(inChapter chapter: Int) -> [Verse] {
        verses.filter { $0.chapter == chapter }
    }

    /// How many verses have been through the enrichment pipeline.
    var enrichedCount: Int { verses.count(where: \.isEnriched) }

    func chapter(_ number: Int) -> Chapter? {
        chapters.first { $0.id == number }
    }
}

extension Library {
    /// An in-memory library for previews, so `#Preview` never touches the bundle.
    static func preview() -> Library {
        let library = Library()
        library.verses = [
            Verse(
                id: 1, chapter: 1, sutra: 1,
                sanskrit: "धृतराष्ट्र उवाच\n\nधर्मक्षेत्रे कुरुक्षेत्रे समवेता युयुत्सवः।\n\nमामकाः पाण्डवाश्चैव किमकुर्वत सञ्जय।।1.1।।",
                transliteration: "dhṛtarāṣṭra uvāca\ndharmakṣetre kurukṣetre samavetā yuyutsavaḥ\nmāmakāḥ pāṇḍavāścaiva kimakurvata sañjaya",
                hindiTranslation: nil, englishTranslation: nil,
                hindiMeaning: nil, englishMeaning: nil,
                wordByWordHindi: #"[{"w":"धर्मक्षेत्रे","m":"धर्म की भूमि में"},{"w":"कुरुक्षेत्रे","m":"कुरुक्षेत्र में"}]"#,
                wordByWordEnglish: #"[{"w":"dharmakṣetre","m":"on the field of dharma"},{"w":"kurukṣetre","m":"at Kurukshetra"}]"#
            ),
            Verse(
                id: 60, chapter: 2, sutra: 47,
                sanskrit: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।मा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि।।2.47।।",
                transliteration: nil, hindiTranslation: nil, englishTranslation: nil,
                hindiMeaning: nil, englishMeaning: nil,
                wordByWordHindi: nil, wordByWordEnglish: nil
            ),
        ]
        library.state = .ready
        return library
    }
}
