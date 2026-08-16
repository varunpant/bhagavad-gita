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

    private(set) var verses: [Verse] = [] { didSet { reindex() } }
    private(set) var chapters: [Chapter] = []

    /// Verse id → its position in `verses`, built once when the corpus loads.
    ///
    /// Six places used to answer "which verse is this id?" with `first(where:)`
    /// over 701 elements, several of them from inside a SwiftUI `body` that
    /// re-runs on every frame of a page turn. One dictionary makes all of them
    /// a lookup.
    private var indexByID: [Int: Int] = [:]
    /// Chapter number → its verses, in order. Same argument.
    private var versesByChapter: [Int: [Verse]] = [:]
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

            let corpus = verses, version = contentVersion
            Task { @concurrent in
                SharedVerses.exportIfNeeded(corpus, contentVersion: version)
            }
        } catch {
            state = .failed(error.localizedDescription)
            Self.logger.error("Failed to load verses: \(error.localizedDescription)")
        }
    }

    /// One connection for the corpus load and for every search. Opening a new
    /// one per keystroke threw away SQLite's page cache each time.
    private nonisolated static let content: ContentDatabase? = try? ContentDatabase()

    @concurrent
    private static func fetchAll() async throws -> (verses: [Verse], chapters: [Chapter], version: String) {
        let database = try content ?? ContentDatabase()
        return (try database.allVerses(),
                try database.allChapters(),
                try database.contentVersion() ?? "0")
    }

    /// Full-text search, off the main actor.
    @concurrent
    static func search(_ query: String) async throws -> [SearchHit] {
        try (content ?? ContentDatabase()).search(query)
    }

    private func reindex() {
        indexByID = Dictionary(
            uniqueKeysWithValues: verses.enumerated().map { ($0.element.id, $0.offset) }
        )
        versesByChapter = Dictionary(grouping: verses, by: \.chapter)
    }

    /// Verses of one chapter, in order.
    func verses(inChapter chapter: Int) -> [Verse] { versesByChapter[chapter] ?? [] }

    func verse(id: Int) -> Verse? { index(of: id).map { verses[$0] } }

    /// Position in reading order, for the pager and the progress rail.
    func index(of verseID: Int) -> Int? { indexByID[verseID] }
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
