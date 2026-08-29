//
//  WelcomeView.swift
//  Gita
//

import SwiftUI

/// The welcome slider, which is also the guide.
///
/// Shown once on a first launch, and reachable afterwards from Settings — the
/// same six pages either way. An onboarding a reader can never see again is a
/// help screen thrown away after one use, and this app has enough in it to be
/// worth explaining twice.
///
/// **The first page asks which script to read in**, and everything after it is
/// written in that script. The reader's first verse can then never arrive in an
/// alphabet they cannot read, and the language switch is demonstrated by being
/// used rather than described.
///
/// On the brand ramp, like the splash it follows: the app opens saffron, and
/// this is the same surface carrying on rather than a second visual idea.
///
/// Paged with `ScrollView` + `.scrollTargetBehavior(.paging)` rather than a
/// `TabView` page style, which does not exist on macOS — the reader's own pager
/// is built the same way, so the two agree about what a page turn is.
struct WelcomeView: View {
    /// What the closing button does. From a first launch it puts the welcome
    /// away for good; from Settings it just dismisses.
    var onFinish: () -> Void

    @Environment(Settings.self) private var settings
    @Environment(Library.self) private var library
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Int? = 0

    private var isDevanagari: Bool { settings.language.isDevanagari }
    private var pages: [WelcomePage] { WelcomePage.all }

    var body: some View {
        VStack(spacing: 0) {
            skip

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { item in
                        page(item)
                            .containerRelativeFrame(.horizontal)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)

            dots
            advance
        }
        .background(Brand.gradient.ignoresSafeArea())
        .preferredColorScheme(.light)   // white on saffron, in every theme
    }

    // MARK: - Chrome

    /// Only while there is somewhere to skip to. On the last page the primary
    /// button says the same thing, and two ways out side by side is one too
    /// many.
    @ViewBuilder
    private var skip: some View {
        HStack {
            Spacer()
            if (page ?? 0) < pages.count - 1 {
                Button(action: finish) {
                    Text(isDevanagari ? "छोड़ें" : "Skip")
                        .font(isDevanagari ? .labelDevanagari : .label)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcomeSkip")
            }
        }
        .frame(height: 44)
        .padding(.trailing, 8)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages) { item in
                Circle()
                    .fill(.white.opacity(item.id == (page ?? 0) ? 1 : 0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 22)
        .accessibilityHidden(true)
    }

    private var advance: some View {
        Button {
            let current = page ?? 0
            if current < pages.count - 1 {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
                    page = current + 1
                }
            } else {
                finish()
            }
        } label: {
            Text(buttonTitle)
                .font(isDevanagari ? .wordDevanagari : .wordLatin)
                .foregroundStyle(Brand.ramp[3])
                .frame(maxWidth: 280)
                .frame(height: 52)
                .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .accessibilityIdentifier("welcomeAdvance")
    }

    private var buttonTitle: String {
        guard (page ?? 0) == pages.count - 1 else {
            return isDevanagari ? "आगे" : "Next"
        }
        return isDevanagari ? "पढ़ना आरंभ करें" : "Begin reading"
    }

    private func finish() {
        Haptics.panel()
        settings.hasSeenWelcome = true
        onFinish()
    }

    // MARK: - A page

    @ViewBuilder
    private func page(_ item: WelcomePage) -> some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            if item.isLanguageChoice {
                blessing
            } else {
                vignette(for: item)
            }

            VStack(spacing: 14) {
                Text(item.title(isDevanagari: isDevanagari))
                    .font(isDevanagari ? .shloka : .shlokaLatin)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.body(isDevanagari: isDevanagari))
                    .font(isDevanagari ? .proseDevanagari : .proseLatin)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Only the first page carries a control: the one setting worth
            // asking for, at the one moment when asking is not an interruption.
            if item.isLanguageChoice { languageChoice }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 34)
        .accessibilityElement(children: .contain)
    }

    /// The screen the page is about, drawn small behind a fade.
    ///
    /// Falls back to the page's symbol only while the corpus is still loading —
    /// a first launch reaches this a moment after the splash, and an empty card
    /// would be worse than a glyph.
    @ViewBuilder
    private func vignette(for item: WelcomePage) -> some View {
        let art = WelcomeVignettes(verse: hero, language: settings.language, theme: theme)

        if hero == nil {
            ZStack {
                Circle().fill(.white.opacity(0.14)).frame(width: 168, height: 168)
                Image(systemName: item.symbol)
                    .font(.system(size: 66, weight: .light))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
        } else {
            WelcomeVignette {
                switch item.id {
                case 1: art.scripture
                case 2: art.reading
                case 3: art.appearance
                case 4: art.finding(searchHits)
                case 5: art.keeping
                default: art.progress(library.chapters, snapshot: sampleProgress)
                }
            }
        }
    }

    /// 2.47 — the verse the whole Gita is quoted for, and the one the store
    /// panels lead with.
    private var hero: Verse? {
        library.verses.first { $0.chapter == 2 && $0.sutra == 47 } ?? library.verses.first
    }

    /// What "karma" actually returns, so the search card is not a mock-up.
    private var searchHits: [Verse] {
        library.verses
            .filter { ($0.englishTranslation ?? "").localizedCaseInsensitiveContains("karma") }
            .prefix(3)
            .map { $0 }
    }

    /// A plausible reading rather than the reader's own, which on a first
    /// launch is nothing at all: an empty ring is a poor advertisement for a
    /// ring. Chapter one finished, a little of chapter two.
    private var sampleProgress: ProgressSnapshot {
        var perChapter: [Int: Int] = [:]
        var sizes: [Int: Int] = [:]
        for chapter in library.chapters { sizes[chapter.id] = chapter.verseCount }
        if let first = library.chapters.first { perChapter[first.id] = first.verseCount }
        if library.chapters.count > 1 { perChapter[library.chapters[1].id] = 38 }

        let read = perChapter.values.reduce(0, +)
        return ProgressSnapshot(
            readVerseIDs: Set(1 ... max(read, 1)),
            versesReadPerChapter: perChapter,
            versesPerChapter: sizes,
            currentStreak: 6,
            longestStreak: 6
        )
    }

    /// The Rigveda's welcome, which is older than the Gita and is what this
    /// tradition says to someone arriving.
    ///
    /// Both scripts here and only here: the reader has not chosen one yet, and
    /// this is the page that asks. Everything after it is in their answer.
    private var blessing: some View {
        VStack(spacing: 12) {
            Text(verbatim: "आ नो भद्राः क्रतवो यन्तु विश्वतः")
                .font(.shloka)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "Let noble thoughts come to us from every side")
                .font(.glossLatin)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "ऋग्वेद १.८९.१  ·  Rigveda 1.89.1")
                .font(.labelDevanagari)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private var languageChoice: some View {
        HStack(spacing: 12) {
            ForEach(ReadingLanguage.allCases) { language in
                Button {
                    Haptics.selection()
                    settings.language = language
                } label: {
                    Text(language.isDevanagari ? "देवनागरी" : "English")
                        .font(language.isDevanagari ? .wordDevanagari : .wordLatin)
                        .foregroundStyle(settings.language == language ? Brand.ramp[3] : .white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(settings.language == language ? AnyShapeStyle(.white)
                                                                    : AnyShapeStyle(.white.opacity(0.18)))
                        }
                        .overlay {
                            Capsule().stroke(.white.opacity(0.5), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcomeLanguage-\(language.rawValue)")
                .accessibilityAddTraits(settings.language == language ? [.isSelected] : [])
            }
        }
        .padding(.top, 4)
    }
}

/// The six pages, as content rather than as views.
///
/// Both languages on every page, like every other pair of strings in the app —
/// the face follows the script, and neither can be chosen without the other.
struct WelcomePage: Identifiable, Sendable {
    let id: Int
    let symbol: String
    let titleSa: String
    let titleEn: String
    let bodySa: String
    let bodyEn: String
    var isLanguageChoice = false

    func title(isDevanagari: Bool) -> String { isDevanagari ? titleSa : titleEn }
    func body(isDevanagari: Bool) -> String { isDevanagari ? bodySa : bodyEn }

    static let all: [WelcomePage] = [
        WelcomePage(
            id: 0, symbol: "hands.sparkles",
            titleSa: "स्वागत है", titleEn: "Welcome",
            bodySa: "आप किस लिपि में पढ़ना चाहेंगे?",
            bodyEn: "Which script would you like to read in?",
            isLanguageChoice: true
        ),
        WelcomePage(
            id: 1, symbol: "book.closed",
            titleSa: "पूरी गीता", titleEn: "The whole Gita",
            bodySa: "सात सौ श्लोक, मूल संस्कृत में — अनुवाद और भावार्थ के साथ। सब कुछ बिना इंटरनेट के।",
            bodyEn: "All 700 verses in the original Sanskrit, with translation and meaning. Everything works offline."
        ),
        WelcomePage(
            id: 2, symbol: "hand.draw",
            titleSa: "पढ़ना", titleEn: "Reading",
            bodySa: "एक श्लोक से दूसरे तक उँगली सरकाएँ। लिपि कभी भी बदल सकते हैं — बाईं पट्टी में अ / A का बटन है।",
            bodyEn: "Swipe from one verse to the next. You can change script whenever you like — the अ / A button is in the left bar."
        ),
        WelcomePage(
            id: 3, symbol: "circle.lefthalf.filled",
            titleSa: "अपने अनुसार", titleEn: "Make it yours",
            bodySa: "प्रकाश, अंधकार या सेपिया — और अक्षरों का आकार अपनी सुविधा से। एकाग्र पाठ में केवल श्लोक रह जाता है; नियंत्रण वापस लाने के लिए दो बार टैप करें।",
            bodyEn: "Light, Dark or Sepia, with the text size to match. Immersive reading leaves the shloka alone on the page — double tap to bring the controls back."
        ),
        WelcomePage(
            id: 4, symbol: "magnifyingglass",
            titleSa: "खोज", titleEn: "Finding",
            bodySa: "किसी शब्द, अर्थ या संख्या — जैसे २.४७ — से तुरंत खोजें, बिना इंटरनेट के।",
            bodyEn: "Search by a word, by a meaning, or by a number like 2.47 — instantly, and offline."
        ),
        WelcomePage(
            id: 5, symbol: "bookmark",
            titleSa: "सहेजना", titleEn: "Keeping",
            bodySa: "जो श्लोक मन को छू जाए उसे सहेज लें, या उसका चित्र बनाकर किसी को भेजें।",
            bodyEn: "Keep a verse that stays with you, or send it to someone as a card."
        ),
        WelcomePage(
            id: 6, symbol: "chart.bar",
            titleSa: "प्रगति और विजेट", titleEn: "Progress and widgets",
            bodySa: "पढ़े हुए श्लोक अंकित होते हैं, अध्याय भरते हैं और लक्ष्य पूरे होते हैं — सब बाईं पट्टी में। होम स्क्रीन पर विजेट आज का श्लोक और आपकी प्रगति दिखाता है।",
            bodyEn: "Verses you read are marked, chapters fill and goals arrive — all in the left bar. On the Home Screen, a widget carries the day's verse and how far you have come."
        ),
    ]
}
