//
//  Embedder.swift
//  Gita
//

import Foundation
import NaturalLanguage
import OSLog

/// Lets exactly one of several racing callbacks resume a continuation.
///
/// Resuming twice is a crash, and never resuming is a hang; both are live risks
/// when a system callback races a timeout.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

/// Turns text into a vector using Apple's on-device contextual embedding.
///
/// Chosen over a bundled CoreML model because it adds nothing to the app
/// download — the model belongs to the OS. The trade-off is that it exists only
/// on Apple platforms, so the corpus vectors cannot be precomputed on a build
/// machine; they are built on device once and cached (see `SemanticIndex`).
///
/// An actor because the underlying model is not safe to use concurrently, and
/// because embedding is slow enough that it must stay off the main actor.
actor Embedder {
    enum Failure: Error, LocalizedError {
        case unsupported
        case assetsUnavailable

        var errorDescription: String? {
            switch self {
            case .unsupported: "Contextual embedding is not available on this device."
            case .assetsUnavailable: "The language model has not been downloaded yet."
            }
        }
    }

    private var embedding: NLContextualEmbedding?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Gita",
        category: "Embedder"
    )

    /// 512 for the English model. Read from the model rather than hardcoded, so
    /// a cache built by a different OS version is detected as incompatible.
    var dimension: Int { embedding?.dimension ?? 0 }

    func load() async throws {
        guard embedding == nil else { return }

        guard let model = NLContextualEmbedding(language: .english) else {
            throw Failure.unsupported
        }

        if !model.hasAvailableAssets {
            // The asset is OS-managed and may need fetching once. This is the
            // only part of the app that ever wants the network, and search stays
            // literal-only until it succeeds.
            //
            // Bounded, because the callback is not guaranteed to fire at all —
            // in the simulator it never does, and an unbounded await there hangs
            // forever rather than degrading. A feature nobody asked for must not
            // be able to wait indefinitely.
            logger.notice("Requesting embedding assets")
            let available = await withCheckedContinuation { continuation in
                let gate = ResumeOnce()
                model.requestAssets { result, _ in
                    if gate.claim() { continuation.resume(returning: result == .available) }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
                    if gate.claim() { continuation.resume(returning: false) }
                }
            }
            guard available else { throw Failure.assetsUnavailable }
        }

        try model.load()
        embedding = model
        logger.info("Embedder ready, \(model.dimension) dimensions")
    }

    /// A single vector for a passage: the mean of its token vectors, then
    /// L2-normalised so that similarity is a plain dot product later.
    func embed(_ text: String) throws -> [Float] {
        guard let embedding else { throw Failure.unsupported }

        let result = try embedding.embeddingResult(for: text, language: .english)
        var pooled = [Float](repeating: 0, count: embedding.dimension)
        var tokens: Float = 0

        result.enumerateTokenVectors(in: text.startIndex ..< text.endIndex) { vector, _ in
            for index in 0 ..< min(vector.count, pooled.count) {
                pooled[index] += Float(vector[index])
            }
            tokens += 1
            return true
        }

        guard tokens > 0 else { return pooled }
        for index in pooled.indices { pooled[index] /= tokens }
        return Self.normalised(pooled)
    }

    /// Unit length, so cosine similarity reduces to a dot product.
    nonisolated static func normalised(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}
