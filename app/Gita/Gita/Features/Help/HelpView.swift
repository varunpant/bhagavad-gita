//
//  HelpView.swift
//  Gita
//

import SwiftUI

/// What every part of the app does, in the reader's own script.
///
/// This replaces the guide's old place on the rail. The welcome slider is an
/// *introduction* — nine pages, seen once, in a fixed order, and it says what
/// the app is for. That is a different job from answering "what does this
/// button do", which is what someone opens a rail panel to find out. The
/// welcome is still there, from Settings; this is the reference beside it.
///
/// **Every entry is written twice**, like every other pair of strings in the
/// app: the face follows the script, and neither is chosen without the other.
/// Which of the two is shown follows `settings.language`, changed from the
/// rail like everywhere else — this panel carried its own script tab for
/// exactly one revision, which was one more switcher than the app has.
/// The topics are in the order a reader meets them — the page in front of them
/// first, then the ways of moving around it, then what the app keeps for them,
/// then how it looks, and the two quiet promises at the end.
struct HelpView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.theme) private var theme

    /// How to put the panel away. Nil when there is nothing to close — a
    /// preview, or a sheet that brings its own chrome.
    var onClose: (() -> Void)?

    private var isDevanagari: Bool { settings.language.isDevanagari }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                sanskrit: "सहायता", english: "HELP", isDevanagari: isDevanagari,
                closeLabel: "Close help", onClose: onClose
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(HelpTopic.all) { topic in
                        row(topic)
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .background(theme.background)
    }

    // MARK: - A topic

    private func row(_ topic: HelpTopic) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // A fixed column, so every title starts on the same line however
            // wide its symbol happens to be drawn.
            Image(systemName: topic.symbol)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(theme.accent)
                .frame(width: 26, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(topic.title(isDevanagari: isDevanagari))
                    .font(isDevanagari ? .wordDevanagari : .wordLatin)
                    .foregroundStyle(theme.textPrimary)

                Text(topic.body(isDevanagari: isDevanagari))
                    .font(isDevanagari ? .glossDevanagari : .glossLatin)
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The small print, set like small print.
    ///
    /// Not a topic, and deliberately not shaped like one: no symbol, no title,
    /// no left edge shared with the list above it. Centred under a short rule
    /// at caption size, the way the line about where a thing was made sits on
    /// the back of a box. It is the last thing on the panel because it is true
    /// of everything above it rather than of any one entry.
    ///
    /// Tracking on the Latin only. It suits letterspaced small caps and
    /// damages Devanagari, which is already spaced by its own headline — the
    /// same rule `PanelHeader` and the welcome's kicker follow.
    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle()
                .fill(theme.divider)
                .frame(width: 40, height: 1)

            Text(isDevanagari
                 ? "सब कुछ आपके उपकरण पर रहता है। न कोई खाता, न विज्ञापन, न कोई अनुसरण।"
                 : "Everything stays on your device. There is no account, no advertising and no tracking.")
                .font(isDevanagari ? .labelDevanagari : .label)
                .tracking(isDevanagari ? 0 : 0.4)
                .foregroundStyle(theme.textSecondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }
}

// MARK: - Content

/// One entry in the help panel, as content rather than as a view.
///
/// Held as data for the same reason `WelcomePage` is: the wording is the part
/// worth reviewing, and it is easier to read — and to check both scripts say
/// the same thing — as a list than as a hundred lines of nested views.
struct HelpTopic: Identifiable, Sendable {
    let id: Int
    let symbol: String
    let titleSa: String
    let titleEn: String
    let bodySa: String
    let bodyEn: String

    func title(isDevanagari: Bool) -> String { isDevanagari ? titleSa : titleEn }
    func body(isDevanagari: Bool) -> String { isDevanagari ? bodySa : bodyEn }

    static let all: [HelpTopic] = [
        HelpTopic(
            id: 0, symbol: "book",
            titleSa: "श्लोक पढ़ना", titleEn: "Reading a verse",
            bodySa: "हर पृष्ठ पर एक श्लोक: मूल पाठ, अनुवाद, भावार्थ और हर शब्द का अर्थ। आगे या पीछे जाने के लिए बाएँ या दाएँ सरकाएँ, या नीचे बने तीरों को दबाएँ। इनमें से कौन-से भाग दिखें, यह सेटिंग्स में “Verse details” के अंतर्गत तय करें।",
            bodyEn: "Every page shows one verse: the Sanskrit shloka, its translation, its meaning, and every word explained. Swipe left or right to move between verses, or use the arrows at the bottom of the page. Choose which of these sections you want in Settings, under Verse details."
        ),
        HelpTopic(
            id: 1, symbol: "list.bullet",
            titleSa: "अनुक्रम", titleEn: "Contents",
            bodySa: "अनुक्रम में अठारहों अध्याय और उनके सभी श्लोक हैं। पढ़े हुए श्लोक चिह्नित रहते हैं, और हर अध्याय के आगे उसकी प्रगति दिखती है। किसी भी संख्या को दबाकर सीधे वहाँ पहुँचें।",
            bodyEn: "The contents list all eighteen chapters and every verse in them. Verses you have read are marked, and each chapter shows how much of it you have read. Tap any number to open that verse."
        ),
        HelpTopic(
            id: 2, symbol: "sparkles",
            titleSa: "प्रसिद्ध श्लोक", titleEn: "Well-known verses",
            bodySa: "अनुक्रम में कुछ श्लोक-संख्याओं के चारों ओर सुनहरा घेरा होता है। ये वे श्लोक हैं जो सबसे अधिक उद्धृत किए जाते हैं, जैसे २.४७ और १८.६६। घेरा श्लोक के बारे में है, आपकी प्रगति के बारे में नहीं। प्रगति घेरे के भराव से दिखती है।",
            bodyEn: "Some verse numbers in the contents have a gold ring around them. These are the verses people quote most often, such as 2.47 and 18.66. The ring is about the verse, not about your progress. Your progress is shown by how the circle is filled."
        ),
        HelpTopic(
            id: 3, symbol: "magnifyingglass",
            titleSa: "खोज", titleEn: "Search",
            bodySa: "शब्द, अर्थ या संख्या से खोजें। सीधे किसी श्लोक तक पहुँचने के लिए २.४७ लिखें। खोज आपके उपकरण पर ही होती है, इसलिए तुरंत है और इंटरनेट नहीं चाहिए। ठीक मिलान के नीचे “संबंधित” में भाव से मिलते-जुलते श्लोक दिखते हैं।",
            bodyEn: "Search by word, by meaning, or by verse number. Type 2.47 to go straight to that verse. Search runs on your device, so it is instant and works without an internet connection. Below the exact matches, Related shows verses that are similar in meaning."
        ),
        HelpTopic(
            id: 4, symbol: "bookmark",
            titleSa: "संग्रह", titleEn: "Bookmarks",
            bodySa: "श्लोक सहेजने के लिए ऊपर बने चिह्न को दबाएँ। सहेजे हुए श्लोक उसी क्रम में मिलते हैं जिस क्रम में वे ग्रंथ में आते हैं।",
            bodyEn: "Tap the bookmark icon at the top of a verse to save it. Your saved verses are listed in the order they appear in the book, so they are easy to find again."
        ),
        HelpTopic(
            id: 5, symbol: "square.and.arrow.up",
            titleSa: "साझा करना", titleEn: "Sharing",
            bodySa: "हर श्लोक कड़ी के रूप में या चित्र के रूप में भेजा जा सकता है। चित्र आपके उपकरण पर बनता है, उसी लिपि में जिसमें आप पढ़ रहे हैं।",
            bodyEn: "You can send any verse as a link or as an image. The image is created on your device, in whichever script you are reading."
        ),
        HelpTopic(
            id: 6, symbol: "chart.bar",
            titleSa: "प्रगति और लक्ष्य", titleEn: "Progress and goals",
            bodySa: "पढ़ते समय श्लोक अपने आप अंकित होते जाते हैं। कुछ भी दबाना नहीं पड़ता। राह में पैंतीस लक्ष्य मिलते हैं, और मिला हुआ कभी वापस नहीं लिया जाता।",
            bodyEn: "Verses are marked as read as you go, so there is nothing to tick off yourself. Thirty-five goals unlock along the way, and nothing you have earned is ever taken away."
        ),
        HelpTopic(
            id: 7, symbol: "rectangle.portrait",
            titleSa: "एकाग्र पाठ", titleEn: "Immersive reading",
            bodySa: "सेटिंग्स में एकाग्र पाठ चालू करें, और पृष्ठ पर केवल श्लोक रह जाएगा। पढ़ते समय बाकी सब छिपा रहता है। नियंत्रण वापस लाने के लिए पृष्ठ पर कहीं भी दो बार दबाएँ।",
            bodyEn: "Turn on Immersive reading in Settings to leave nothing on the page but the shloka. Everything else stays hidden while you read. Double-tap anywhere on the page to bring the controls back."
        ),
        HelpTopic(
            id: 8, symbol: "textformat.size",
            titleSa: "रूप और अक्षर-आकार", titleEn: "Appearance and text size",
            bodySa: "सेटिंग्स में प्रकाश, अंधकार या सेपिया चुनें, और अपनी सुविधा का अक्षर-आकार तय करें। ऐप का हर पृष्ठ उसी रूप में ढल जाता है।",
            bodyEn: "Choose Light, Dark or Sepia in Settings, and set the text size that suits you. Every page in the app follows that choice."
        ),
        HelpTopic(
            id: 9, symbol: "character",
            titleSa: "लिपि बदलना", titleEn: "Changing script",
            bodySa: "बाईं पट्टी का अक्षर पूरे ऐप को देवनागरी और हिंदी से लिप्यंतरण और अंग्रेज़ी में बदल देता है। केवल श्लोक नहीं, हर शब्द इसके साथ बदलता है।",
            bodyEn: "The letter on the bar at the left switches the whole app between two scripts: Devanagari with Hindi, and transliteration with English. Everything changes with it, not only the verse."
        ),
        HelpTopic(
            id: 10, symbol: "calendar",
            titleSa: "प्रतिदिन एक श्लोक", titleEn: "A verse every day",
            bodySa: "अपने समय पर एक स्मरण लगाएँ, और होम स्क्रीन पर विजेट जोड़ें। दोनों हर दिन वही श्लोक दिखाते हैं, बिना ऐप खोले।",
            bodyEn: "Set a daily reminder for a time that suits you, and add a widget to your Home Screen. Both show the same verse each day, so you can read it without opening the app."
        ),
    ]
}
