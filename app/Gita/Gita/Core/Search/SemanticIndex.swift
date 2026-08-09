//
//  SemanticIndex.swift
//  Gita
//

import Accelerate
import Foundation
import Observation
import OSLog

/// Vectors for the whole corpus, held as one flat buffer.
///
/// Flat rather than `[[Float]]` so the similarity pass is a single matrix
/// multiply through Accelerate instead of 701 separate dot products.
nonisolated struct VerseVectors: Sendable {
    let ids: [Int]
    let dimension: Int
    /// `ids.count * dimension` values, row-major, each row centred and unit length.
    let values: [Float]
    /// Mean of the raw corpus vectors, subtracted from every vector including
    /// the query's. Without it a handful of "hub" verses sit close to every
    /// query and dominate every result — measured here, 6.40 and 2.19 came back
    /// for questions about grief, duty and the soul alike. Removing the common
    /// component is what makes the remaining distance mean something.
    let mean: [Float]

    var count: Int { ids.count }
}

/// Semantic search over the verses: meaning, not spelling.
///
/// Complements full-text search rather than replacing it. FTS5 answers
/// "krishna" and "2.47"; this answers "how do I deal with grief", where none of
/// the query's words appear in the verse.
///
/// The index is built on device, once, and cached. Everything about it degrades
/// quietly: if the OS embedding asset is missing, or indexing fails, search
/// stays literal and the reader is never shown an error for a feature they did
/// not ask for.
@Observable
final class SemanticIndex {
    enum State: Equatable {
        case idle
        case building(done: Int, total: Int)
        case ready
        case unavailable

        var isReady: Bool { self == .ready }
    }

    private(set) var state: State = .idle
    private var vectors: VerseVectors?
    private let embedder = Embedder()

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "SemanticIndex"
    )

    /// Cache lives beside the user database and is keyed by content version, so
    /// shipping a new gita.sqlite rebuilds it rather than silently searching the
    /// old text.
    private nonisolated static func cacheURL(contentVersion: String) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return support.appendingPathComponent("semantic-index-v\(contentVersion).bin")
    }

    // MARK: - Building

    /// Load from cache, or build and cache. Safe to call on every launch.
    func prepare(verses: [Verse], contentVersion: String) async {
        guard state == .idle else { return }

        if let cached = try? Self.readCache(contentVersion: contentVersion),
           cached.count == verses.count {
            vectors = cached
            state = .ready
            Self.logger.info("Semantic index loaded from cache (\(cached.count) verses)")
            return
        }

        do {
            try await embedder.load()
        } catch {
            state = .unavailable
            Self.logger.notice("Semantic search unavailable: \(error.localizedDescription)")
            return
        }

        state = .building(done: 0, total: verses.count)
        let dimension = await embedder.dimension

        var ids: [Int] = []
        var values: [Float] = []
        ids.reserveCapacity(verses.count)
        values.reserveCapacity(verses.count * dimension)

        for (offset, verse) in verses.enumerated() {
            guard !Task.isCancelled else { state = .idle; return }
            guard let text = Self.passage(for: verse) else { continue }
            guard let vector = try? await embedder.embed(text), vector.count == dimension else { continue }
            ids.append(verse.id)
            values.append(contentsOf: vector)

            // Cheap progress, without re-rendering on every single verse.
            if offset % 50 == 0 { state = .building(done: offset, total: verses.count) }
        }

        guard !ids.isEmpty else {
            state = .unavailable
            return
        }

        let built = Self.centred(ids: ids, dimension: dimension, values: values)
        vectors = built
        state = .ready
        try? Self.writeCache(built, contentVersion: contentVersion)
        Self.logger.info("Semantic index built for \(ids.count) verses")
    }

    /// Subtract the corpus mean from every vector, then renormalise.
    nonisolated static func centred(ids: [Int], dimension: Int, values: [Float]) -> VerseVectors {
        var mean = [Float](repeating: 0, count: dimension)
        for row in 0 ..< ids.count {
            for column in 0 ..< dimension {
                mean[column] += values[row * dimension + column]
            }
        }
        let count = Float(ids.count)
        for column in 0 ..< dimension { mean[column] /= count }

        var centred = values
        for row in 0 ..< ids.count {
            var vector = [Float](repeating: 0, count: dimension)
            for column in 0 ..< dimension {
                vector[column] = values[row * dimension + column] - mean[column]
            }
            let unit = Embedder.normalised(vector)
            for column in 0 ..< dimension { centred[row * dimension + column] = unit[column] }
        }

        return VerseVectors(ids: ids, dimension: dimension, values: centred, mean: mean)
    }

    /// What actually gets embedded. The model is English, so the English
    /// translation and meaning carry the sense; the Sanskrit would only add
    /// noise, and remains fully searchable through FTS5.
    private nonisolated static func passage(for verse: Verse) -> String? {
        let parts = [verse.englishTranslation, verse.englishMeaning].compactMap { $0 }
        let text = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: - Searching

    /// Verse ids most similar to the query, best first.
    ///
    /// One matrix-vector multiply over the whole corpus: 701 × 512 floats is
    /// under a megabyte, so this is sub-millisecond and needs no index
    /// structure. A larger corpus would want one; this one genuinely does not.
    ///
    /// Selection is **relative**, not an absolute threshold. Mean-pooled
    /// contextual embeddings sit in a narrow band — measured here, every verse
    /// scores 0.85-0.92 against any English query — so a fixed cut-off either
    /// admits the entire corpus or none of it. What carries the signal is the
    /// gap below the best match, so results are kept within `margin` of the top
    /// score and capped at `topK`.
    func search(_ query: String, topK: Int = 20, margin: Float = 0.035) async -> [Int] {
        guard state.isReady, let vectors else { return [] }
        // The cache path returns before ever loading the embedder, so the query
        // still needs a model even when the corpus vectors came off disk.
        // `load()` is idempotent and returns immediately once ready.
        guard (try? await embedder.load()) != nil else { return [] }
        guard let raw = try? await embedder.embed(query), raw.count == vectors.dimension else {
            return []
        }
        let vector = Embedder.normalised(zip(raw, vectors.mean).map(-))

        var scores = [Float](repeating: 0, count: vectors.count)
        vDSP_mmul(vectors.values, 1, vector, 1, &scores, 1,
                  vDSP_Length(vectors.count), 1, vDSP_Length(vectors.dimension))

        let ranked = zip(vectors.ids, scores).sorted { $0.1 > $1.1 }
        guard let best = ranked.first?.1 else { return [] }

        return ranked
            .prefix(topK)
            .filter { $0.1 >= best - margin }
            .map(\.0)
    }

    /// Scores without the cut-off, for calibrating `minimumScore`.
    func scoredForDiagnostics(_ query: String, topK: Int) async -> [(Int, Float)] {
        guard state.isReady, let vectors else { return [] }
        guard (try? await embedder.load()) != nil else { return [] }
        guard let raw = try? await embedder.embed(query), raw.count == vectors.dimension else { return [] }
        let vector = Embedder.normalised(zip(raw, vectors.mean).map(-))
        var scores = [Float](repeating: 0, count: vectors.count)
        vDSP_mmul(vectors.values, 1, vector, 1, &scores, 1,
                  vDSP_Length(vectors.count), 1, vDSP_Length(vectors.dimension))
        return zip(vectors.ids, scores).sorted { $0.1 > $1.1 }.prefix(topK).map { ($0.0, $0.1) }
    }

    // MARK: - Cache

    private nonisolated static let magic: UInt32 = 0x47_49_54_41   // "GITA"
    /// Bumped when the on-disk shape changes, so an older cache is ignored
    /// rather than misread. Version 2 added the corpus mean.
    private nonisolated static let format: UInt32 = 2

    private nonisolated static func writeCache(_ vectors: VerseVectors, contentVersion: String) throws {
        var data = Data()
        var header = [magic, format, UInt32(vectors.count), UInt32(vectors.dimension)]
        header.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
        vectors.mean.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
        vectors.ids.map(Int32.init).withUnsafeBufferPointer { data.append(Data(buffer: $0)) }
        vectors.values.withUnsafeBufferPointer { data.append(Data(buffer: $0)) }

        try data.write(to: cacheURL(contentVersion: contentVersion), options: .atomic)
    }

    private nonisolated static func readCache(contentVersion: String) throws -> VerseVectors? {
        let url = try cacheURL(contentVersion: contentVersion)
        guard let data = try? Data(contentsOf: url), data.count > 16 else { return nil }

        let header = data.prefix(16).withUnsafeBytes {
            $0.loadUnaligned(as: (UInt32, UInt32, UInt32, UInt32).self)
        }
        guard header.0 == magic, header.1 == format else { return nil }

        let count = Int(header.2), dimension = Int(header.3)
        let meanBytes = dimension * MemoryLayout<Float>.size
        let idBytes = count * MemoryLayout<Int32>.size
        let valueBytes = count * dimension * MemoryLayout<Float>.size
        guard data.count == 16 + meanBytes + idBytes + valueBytes else { return nil }

        let mean: [Float] = data[16 ..< 16 + meanBytes].withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        let ids: [Int] = data[(16 + meanBytes) ..< (16 + meanBytes + idBytes)].withUnsafeBytes {
            Array($0.bindMemory(to: Int32.self)).map(Int.init)
        }
        let values: [Float] = data[(16 + meanBytes + idBytes)...].withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        return VerseVectors(ids: ids, dimension: dimension, values: values, mean: mean)
    }
}
