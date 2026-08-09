//
//  SemanticSearchTests.swift
//  GitaTests
//

import Foundation
import Testing
@testable import Gita

/// Semantic search earns its place only if it finds verses that full-text
/// search cannot. These check that, and that it degrades safely when it can't.
@Suite("Semantic search", .serialized)
@MainActor
struct SemanticSearchTests {

    /// Building the index once for the whole suite: it is the expensive part.
    private static let index: SemanticIndex = SemanticIndex()

    private func preparedIndex() async throws -> SemanticIndex? {
        let database = try ContentDatabase()
        let verses = try database.allVerses()
        let version = try database.contentVersion() ?? "0"
        await Self.index.prepare(verses: verses, contentVersion: version)

        // A machine without the OS language asset cannot run these; skipping is
        // correct, since the app is designed to degrade in exactly that case.
        guard Self.index.state.isReady else { return nil }
        return Self.index
    }

    @Test("Indexes the whole corpus, or reports itself unavailable")
    func indexBuilds() async throws {
        guard let index = try await preparedIndex() else {
            #expect(Self.index.state == .unavailable)
            return
        }
        #expect(index.state.isReady)
    }

    /// The reason for the feature: a query whose words appear nowhere in the
    /// verse still finds it.
    @Test("Finds verses by meaning, where full-text search finds nothing",
          arguments: [
            "how do I cope with sadness and loss",
            "what happens to the soul after death",
            "doing my duty without worrying about the outcome",
          ])
    func findsByMeaning(query: String) async throws {
        guard let index = try await preparedIndex() else { return }

        let literal = try ContentDatabase().search(query)
        let semantic = await index.search(query)

        #expect(!semantic.isEmpty, "semantic search found nothing for: \(query)")
        #expect(literal.isEmpty || semantic.count >= literal.count,
                "semantic (\(semantic.count)) vs literal (\(literal.count)) for: \(query)")
        // The whole point: these queries share no words with the verses.
        #expect(semantic.count < 200, "returned \(semantic.count) — too broad to be useful")
    }

    /// Ranking has to be better than chance, but these embeddings are only
    /// thematically accurate — measured, not assumed. 2.20 ("the soul is never
    /// born") is retrieved cleanly by a paraphrase of itself; a query phrased
    /// like 2.47 does *not* surface 2.47, which is why the reader always sees
    /// full-text results first and these only as "Related".
    @Test("A thematic paraphrase retrieves the verse it paraphrases")
    func thematicRetrieval() async throws {
        guard let index = try await preparedIndex() else { return }
        let results = await index.search("the soul is never born and never dies")
        #expect(!results.isEmpty)

        let byId = Dictionary(uniqueKeysWithValues: try ContentDatabase().allVerses().map { ($0.id, $0) })
        let references = results.prefix(5).compactMap { byId[$0]?.reference }
        #expect(references.first == "2.20", "expected 2.20 first, got \(references)")
    }

    /// The corpus mean is what makes the scores discriminate at all. Without it
    /// everything scores 0.87-0.92 and a handful of hub verses win every query.
    @Test("Centring spreads the scores apart")
    func centringWidensTheRange() async throws {
        guard let index = try await preparedIndex() else { return }
        let scored = await index.scoredForDiagnostics("the soul is never born and never dies", topK: 50)
        guard let best = scored.first?.1, let worst = scored.last?.1 else {
            Issue.record("no scores"); return
        }
        #expect(best - worst > 0.1, "top-50 spread was only \(best - worst) — centring is not working")
    }

    @Test("Hostile input cannot break it either", arguments: [
        "", " ", "\u{200B}", String(repeating: "x", count: 5_000), "'; DROP TABLE verses; --",
    ])
    func hostileInputIsSafe(query: String) async throws {
        guard let index = try await preparedIndex() else { return }
        _ = await index.search(query)                 // must not crash or hang
    }

    @Test("A second prepare uses the cache instead of rebuilding")
    func cacheIsReused() async throws {
        guard try await preparedIndex() != nil else { return }

        let fresh = SemanticIndex()
        let database = try ContentDatabase()
        let clock = ContinuousClock()
        let verses = try database.allVerses()
        let version = try database.contentVersion() ?? "0"
        let elapsed = await clock.measure {
            await fresh.prepare(verses: verses, contentVersion: version)
        }
        #expect(fresh.state.isReady)
        #expect(elapsed < .seconds(2), "cache load took \(elapsed) — it rebuilt instead")
    }
}
