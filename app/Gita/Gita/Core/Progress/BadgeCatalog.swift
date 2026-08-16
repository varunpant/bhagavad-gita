//
//  BadgeCatalog.swift
//  Gita
//

import Foundation

/// The 35 badges, in the order they are shown.
///
/// Named from the Gita's own vocabulary rather than invented titles: a reader
/// who reaches स्थितप्रज्ञ has met the word in 2.55 already.
nonisolated enum BadgeCatalog {

    static let all: [Badge] = verses + chapters + streaks + landmarks

    /// Grouped once rather than filtered per call — the progress panel asks for
    /// each family several times per render.
    private static let byFamily: [Badge.Family: [Badge]] = Dictionary(grouping: all, by: \.family)

    static func all(in family: Badge.Family) -> [Badge] { byFamily[family] ?? [] }

    // MARK: - Verses read (7)

    private static let verses: [Badge] = [
        badge("verses_1", "प्रथम पद", "First Step", 1, "figure.walk"),
        badge("verses_10", "जिज्ञासु", "The Enquirer", 10, "sparkles"),
        badge("verses_50", "साधक", "The Seeker", 50, "leaf"),
        badge("verses_100", "अभ्यासी", "The Practitioner", 100, "flame"),
        badge("verses_250", "स्थितप्रज्ञ", "Steady in Wisdom", 250, "mountain.2"),
        badge("verses_500", "ज्ञानी", "The Knower", 500, "sun.max"),
        badge("verses_701", "गीता पूर्ण", "Gita Complete", 701, "crown"),
    ]

    private static func badge(
        _ id: String, _ sa: String, _ en: String, _ count: Int, _ symbol: String
    ) -> Badge {
        Badge(
            id: id, titleSa: sa, titleEn: en,
            detailSa: "\(count.devanagariDigits) श्लोक पढ़ें",
            detailEn: count == 1 ? "Read your first verse" : "Read \(count) verses",
            symbol: symbol, family: .verses, requirement: .versesRead(count)
        )
    }

    // MARK: - Chapters (18)

    /// One per chapter, titled with that chapter's own yoga and given its own
    /// symbol — Arjuna's despair a rain cloud, the cosmic form a globe,
    /// devotion a heart, liberation a sunrise. Eighteen identical book icons
    /// said nothing about which chapter was which.
    ///
    /// This is the family that unlocks most often, because finishing a chapter
    /// is how people actually read the Gita.
    private static let chapters: [Badge] = [
        (1, "अर्जुनविषादयोग", "The Despondency of Arjuna", "cloud.rain"),
        (2, "सांख्ययोग", "Transcendental Knowledge", "brain"),
        (3, "कर्मयोग", "The Path of Action", "hammer"),
        (4, "ज्ञानकर्मसंन्यासयोग", "Knowledge and the Renunciation of Action", "books.vertical"),
        (5, "कर्मसंन्यासयोग", "The Path of Renunciation", "hand.raised"),
        (6, "आत्मसंयमयोग", "The Path of Meditation", "figure.mind.and.body"),
        (7, "ज्ञानविज्ञानयोग", "Knowledge and Realisation", "lightbulb"),
        (8, "अक्षरब्रह्मयोग", "The Imperishable Brahman", "atom"),
        (9, "राजविद्याराजगुह्ययोग", "The Royal Knowledge", "key"),
        (10, "विभूतियोग", "The Divine Manifestations", "star"),
        (11, "विश्वरूपदर्शनयोग", "The Vision of the Cosmic Form", "globe.asia.australia"),
        (12, "भक्तियोग", "The Path of Devotion", "heart"),
        (13, "क्षेत्रक्षेत्रज्ञविभागयोग", "The Field and its Knower", "square.grid.3x3"),
        (14, "गुणत्रयविभागयोग", "The Three Gunas", "triangle"),
        (15, "पुरुषोत्तमयोग", "The Supreme Person", "tree"),
        (16, "दैवासुरसम्पद्विभागयोग", "Divine and Demoniac Natures", "theatermasks"),
        (17, "श्रद्धात्रयविभागयोग", "The Three Kinds of Faith", "flame.circle"),
        (18, "मोक्षसंन्यासयोग", "Liberation through Renunciation", "sunrise"),
    ].map { number, sa, en, symbol in
        Badge(
            id: "chapter_\(number)", titleSa: sa, titleEn: en,
            detailSa: "अध्याय \(number.devanagariDigits) पूर्ण",
            detailEn: "Finish chapter \(number)",
            symbol: symbol, family: .chapters,
            requirement: .chapterComplete(number)
        )
    }

    // MARK: - Streaks (4)

    private static let streaks: [Badge] = [
        (7, "सप्ताह", "A Week"),
        (30, "मास", "A Month"),
        (100, "शतक", "A Hundred Days"),
        (365, "संवत्सर", "A Year"),
    ].map { days, sa, en in
        Badge(
            id: "streak_\(days)", titleSa: sa, titleEn: en,
            detailSa: "\(days.devanagariDigits) दिन लगातार",
            detailEn: "Read \(days) days in a row",
            symbol: "flame", family: .streaks,
            requirement: .currentStreak(days)
        )
    }

    // MARK: - Landmarks (6)

    /// Reaching a verse people know by heart. Unlocked by verse id, so they
    /// arrive whenever the reader gets there — in order or not.
    private static let landmarks: [Badge] = [
        (67, "अविनाशी", "The Imperishable", "2.20", "infinity"),
        (94, "कर्मण्येवाधिकारस्ते", "Yours Is the Action", "2.47", "hands.sparkles"),
        (169, "यदा यदा हि धर्मस्य", "Whenever Dharma Declines", "4.7", "arrow.clockwise"),
        (360, "योगक्षेमं वहाम्यहम्", "I Carry What You Lack", "9.22", "hands.and.sparkles"),
        (446, "कालोऽस्मि", "I Am Time", "11.32", "hourglass"),
        (689, "सर्वधर्मान्परित्यज्य", "Abandon All Dharmas", "18.66", "bird"),
    ].map { verseID, sa, en, reference, symbol in
        Badge(
            id: "landmark_\(reference)", titleSa: sa, titleEn: en,
            detailSa: "श्लोक \(reference) तक पहुँचें",
            detailEn: "Reach verse \(reference)",
            symbol: symbol, family: .landmarks,
            requirement: .verseReached(verseID)
        )
    }
}
