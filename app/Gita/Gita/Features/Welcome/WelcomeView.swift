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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Int? = 0

    private var isDevanagari: Bool { settings.language.isDevanagari }
    private var pages: [WelcomePage] { WelcomePage.all }

    /// An iPad or a Mac is not a large phone. Everything here — the card, the
    /// title, the body — is bigger there, and bigger on the phone than it was:
    /// the first version left a third of the screen empty on both.
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass != .compact }
    #else
    private var isRegular: Bool { true }
    #endif

    private var titleFont: Font {
        isDevanagari
            ? .custom("KohinoorDevanagari-Light", size: isRegular ? 52 : 34)
            : .custom("Georgia", size: isRegular ? 50 : 33)
    }

    private var bodyFont: Font {
        isDevanagari
            ? .custom("KohinoorDevanagari-Light", size: isRegular ? 27 : 20)
            : .custom("Georgia", size: isRegular ? 26 : 19)
    }

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
        // White, not the brand ramp. The cards are screenshots of a white app,
        // and a white rectangle floating on saffron read as a hole cut in the
        // page. The ramp stays where it belongs: on the controls.
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
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
                        .foregroundStyle(.secondary)
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
                    .fill(item.id == (page ?? 0)
                          ? AnyShapeStyle(LinearGradient(colors: Brand.ramp,
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.secondary.opacity(0.3)))
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
                .foregroundStyle(.white)
                .frame(maxWidth: 320)
                .frame(height: 56)
                .background(
                    Capsule().fill(LinearGradient(colors: Brand.ramp,
                                                  startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Brand.ramp[3].opacity(0.35), radius: 12, y: 6)
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
        VStack(spacing: isRegular ? 34 : 24) {
            // Barely a gap above a card on a large screen: it belongs near the
            // top, so the title falls just below the middle rather than the
            // whole page hanging in the centre of thirteen inches. The first
            // page has no card and stays centred, or the greeting floats in the
            // top third with the rest of the screen empty under it.
            if isRegular, !item.isLanguageChoice {
                Spacer(minLength: 0).frame(maxHeight: 24)
            } else {
                Spacer(minLength: 0)
            }

            if item.isLanguageChoice {
                blessing
            } else {
                vignette(for: item)
            }

            VStack(spacing: 14) {
                Text(item.title(isDevanagari: isDevanagari))
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.body(isDevanagari: isDevanagari))
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Only the first page carries a control: the one setting worth
            // asking for, at the one moment when asking is not an interruption.
            if item.isLanguageChoice {
                languageChoice
                    .padding(.top, isRegular ? 26 : 18)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isRegular ? 60 : 26)
        .accessibilityElement(children: .contain)
    }

    /// The screen this page is about, as a card.
    @ViewBuilder
    private func vignette(for item: WelcomePage) -> some View {
        WelcomeVignette(art: item.art, isDevanagari: isDevanagari)
    }

    /// The Rigveda's welcome, which is older than the Gita and is what this
    /// tradition says to someone arriving.
    ///
    /// Both scripts here and only here: the reader has not chosen one yet, and
    /// this is the page that asks. Everything after it is in their answer.
    private var blessing: some View {
        VStack(spacing: 14) {
            Text(verbatim: "आ नो भद्राः क्रतवो यन्तु विश्वतः")
                .font(.shloka)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "Let noble thoughts come to us from every side")
                .font(.glossLatin)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: "ऋग्वेद १.८९.१  ·  Rigveda 1.89.1")
                .font(.labelDevanagari)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(.bottom, isRegular ? 30 : 20)
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
                        .foregroundStyle(settings.language == language ? .white : .primary)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(settings.language == language
                                      ? AnyShapeStyle(LinearGradient(colors: Brand.ramp,
                                                                     startPoint: .leading,
                                                                     endPoint: .trailing))
                                      : AnyShapeStyle(Color.clear))
                        }
                        .overlay {
                            Capsule().stroke(
                                settings.language == language ? .clear : .secondary.opacity(0.35),
                                lineWidth: 1
                            )
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
    /// Which screenshot the page shows, without its script suffix.
    var art: String = ""
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
            bodySa: "भाषा चुनें",
            bodyEn: "Select language",
            isLanguageChoice: true
        ),
        WelcomePage(
            id: 1, symbol: "book.closed", art: "scripture",
            titleSa: "सम्पूर्ण गीता", titleEn: "The complete Gita",
            bodySa: "सात सौ श्लोक — अनुवाद और भावार्थ सहित, बिना इंटरनेट के।",
            bodyEn: "All 700 verses, with translation and meaning. Works entirely offline."
        ),
        WelcomePage(
            id: 2, symbol: "hand.draw", art: "contents",
            titleSa: "अध्याय और श्लोक", titleEn: "Chapters and verses",
            bodySa: "श्लोकों के बीच सरकाएँ, या सूची से चुनें। लिपि बाईं पट्टी से बदलें।",
            bodyEn: "Swipe between verses, or pick one from the contents. Change script from the left bar."
        ),
        WelcomePage(
            id: 3, symbol: "circle.lefthalf.filled", art: "appearance",
            titleSa: "रूप और अक्षर-आकार", titleEn: "Appearance and text size",
            bodySa: "प्रकाश, अंधकार या सेपिया, अपने अक्षर-आकार में। एकाग्र पाठ में केवल श्लोक रहता है।",
            bodyEn: "Light, Dark or Sepia, at your text size. Immersive reading leaves only the shloka."
        ),
        WelcomePage(
            id: 4, symbol: "magnifyingglass", art: "search",
            titleSa: "खोज", titleEn: "Search",
            bodySa: "शब्द, अर्थ या संख्या से खोजें — तुरंत, बिना इंटरनेट के।",
            bodyEn: "Search by word, meaning or number — instantly, offline."
        ),
        WelcomePage(
            id: 5, symbol: "bookmark", art: "bookmark",
            titleSa: "संगृहीत और साझा", titleEn: "Bookmarks and sharing",
            bodySa: "श्लोक सहेजें और बाद में लौटें, या चित्र रूप में साझा करें।",
            bodyEn: "Bookmark a verse to return to it, or share it as a card."
        ),
        WelcomePage(
            id: 6, symbol: "chart.bar", art: "progress",
            titleSa: "प्रगति और विजेट", titleEn: "Progress and widgets",
            bodySa: "पढ़े हुए श्लोक अंकित होते हैं और लक्ष्य पूरे होते हैं। विजेट पर आज का श्लोक।",
            bodyEn: "Verses you read are marked and goals arrive. A widget carries the day's verse."
        ),
    ]
}
