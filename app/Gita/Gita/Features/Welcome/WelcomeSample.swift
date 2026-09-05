//
//  WelcomeSample.swift
//  Gita
//

import SwiftUI

// Verse 2.47, typed out so the guide can draw a card without opening the
// database. Pinned to the corpus by `WelcomeSampleTests`.

nonisolated enum WelcomeSample {
    struct Gloss: Sendable { let word: String; let gloss: String }

    /// The first line of the shloka. `gita.sqlite` holds both lines and no
    /// danda — punctuation is presentation, added back by the app — so the
    /// danda here is the app's, and `WelcomeSampleTests` compares without it.
    static let shlokaSa = "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।"
    static let shlokaEn = "karmaṇyevādhikāraste mā phaleṣu kadācana"

    /// Each of these is the opening of what the reader will actually meet at
    /// 2.47 — the first sentence, not a paraphrase of it. They used to be
    /// neither: "You have a right to your action alone, never to its fruits."
    /// is a better line than the corpus has and is not in the corpus, so a
    /// reader who followed the guide to the verse met different words.
    static let translationSa = "तुम्हारा अधिकार केवल कर्म करने में है, उसके फलों में कभी नहीं।"
    static let translationEn = "You have a right to perform your prescribed duty, but you are not entitled to the fruits of action."

    static let meaningSa = "यह श्लोक निष्काम कर्मयोग का मूल सिद्धांत प्रस्तुत करता है।"
    static let meaningEn = "This verse presents the core principle of Nishkama Karma Yoga or selfless action."

    /// The first five glosses, verbatim from `word_by_word_*`.
    static let wordsSa: [Gloss] = [
        Gloss(word: "कर्मणि", gloss: "कर्म में"),
        Gloss(word: "एव", gloss: "ही"),
        Gloss(word: "अधिकारः", gloss: "अधिकार"),
        Gloss(word: "ते", gloss: "तुम्हारा"),
        Gloss(word: "मा", gloss: "नहीं"),
    ]

    static let wordsEn: [Gloss] = [
        Gloss(word: "karmaṇi", gloss: "in prescribed duty"),
        Gloss(word: "eva", gloss: "only"),
        Gloss(word: "adhikāraḥ", gloss: "right"),
        Gloss(word: "te", gloss: "your"),
        Gloss(word: "mā", gloss: "never"),
    ]
}
