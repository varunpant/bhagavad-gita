//
//  WelcomeView.swift
//  Gita
//

import SwiftUI

/// The welcome slider, which is also the guide.
///
/// Shown once on a first launch, and reachable afterwards from Settings — the
/// same nine pages either way. An onboarding a reader can never see again is a
/// help screen thrown away after one use, and this app has enough in it to be
/// worth explaining twice.
///
/// **The first page asks which script to read in**, and everything after it is
/// written in that script. The reader's first verse can then never arrive in an
/// alphabet they cannot read, and the language switch is demonstrated by being
/// used rather than described.
///
/// The ground is a warm white and the colour lives in the type — kicker,
/// heading and body are `Theme.sepia`'s own three tokens, so nothing here is a
/// new palette. Marigold survives in exactly three places: the rule above each
/// heading, the current dot, and the button. That is the discipline the app
/// itself follows — brand on the furniture, never on the reading surface.
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var page: Int? = 0

    /// Whether the page on screen is one whose art runs off the foot.
    ///
    /// Only those want the long fade. On every other page the tall wash reached
    /// 170pt up into art that ends well above it — over the title page it
    /// desaturated the two language pills, which are the one thing that page
    /// exists to collect, and over the cards it greyed out the last lines of
    /// the English one.
    private var currentPageBleeds: Bool {
        pages.first { $0.id == (page ?? 0) }?.isScreenshot ?? false
    }

    /// Debug builds can open the guide at any page, the same way the rail's
    /// panels can be opened from a launch argument. The screenshot pipeline
    /// needs to photograph page seven without tapping through six others, and
    /// so does anyone checking one page's layout on one device.
    private static var startPage: Int? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-welcomePage"),
              index + 1 < arguments.count,
              let value = Int(arguments[index + 1]),
              WelcomePage.all.indices.contains(value)
        else { return nil }
        return value
        #else
        return nil
        #endif
    }

    private var isDevanagari: Bool { settings.language.isDevanagari }
    private var pages: [WelcomePage] { WelcomePage.all }

    /// The guide draws through the safe area rather than inside it.
    ///
    /// Every distance in the reference is measured from an edge of the screen —
    /// the rule 72 below the top, the button 34 above the foot — and a view
    /// laid out inside the safe area cannot honour any of them, because the
    /// inset it is being held off by is a different number on every device.
    /// So the page takes the whole screen, reads the insets as *data*, and
    /// steps around them itself. See `WelcomeMetrics`.
    var body: some View {
        GeometryReader { screen in
            let insets = screen.safeAreaInsets
            let m = WelcomeMetrics(size: screen.size,
                                   safeTop: insets.top,
                                   safeBottom: insets.bottom,
                                   devanagari: isDevanagari)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { item in
                        page(item, insets: insets)
                            .containerRelativeFrame(.horizontal)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            // The controls sit *over* the pages rather than under them, on a
            // scrim that fades the art into the ground. Under them, every page
            // would owe the chrome a fixed strip of its height whether it
            // needed one or not. `zIndex` says so rather than leaving it to
            // the order the modifiers happen to be written in: the button is
            // the one thing on this screen that must never be behind a
            // screenshot, whatever the art does.
            .overlay(alignment: .bottom) { controls(m).zIndex(2) }
            .overlay(alignment: .topTrailing) { close(m).zIndex(3) }
        }
        .ignoresSafeArea()
        .background(WelcomeInk.ground.ignoresSafeArea())
        .preferredColorScheme(.light)
        // After the first layout, so the pager has somewhere to scroll to.
        .task { if let start = Self.startPage { page = start } }
    }

    // MARK: - Chrome

    /// A way out, on every page.
    ///
    /// The guide is nine pages long and is reachable again from Settings, so
    /// there is no reason to make someone swipe to the end of it to leave —
    /// and from a first launch the button at the foot only says "Next" until
    /// the last page, which is a long way to look at before finding out you
    /// could have stopped. Closing counts as having seen it, exactly as
    /// finishing does.
    private func close(_ m: WelcomeMetrics) -> some View {
        Button(action: finish) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WelcomeInk.mute)
                .frame(width: WelcomeMetrics.closeButton, height: WelcomeMetrics.closeButton)
                .background { Circle().fill(WelcomeInk.ink.opacity(0.06)) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 14)
        // Level with the rule above the kicker — see `WelcomeMetrics.closeTop`.
        .padding(.top, m.closeTop)
        .accessibilityIdentifier("welcomeClose")
        .accessibilityLabel(isDevanagari ? "बंद करें" : "Close")
    }

    /// The dots and the button, at a constant height above the foot of the
    /// screen — the same height on every one of the nine pages, and, because
    /// `controlsBottom` pays back whatever the device reserves down there, very
    /// nearly the same height on a phone, an iPad and a Mac window too.
    private func controls(_ m: WelcomeMetrics) -> some View {
        VStack(spacing: WelcomeMetrics.controlsGap) {
            dots
            advance(m)
        }
        .padding(.bottom, m.safeBottom + m.controlsBottom)
        .frame(maxWidth: .infinity)
        // The title page gets a shallow one. Its business is at the foot —
        // the two language pills — and the tall scrim's wash reached 170pt
        // above the controls, far enough to desaturate the selected pill to a
        // muddy brown and half-fade the other. The tall reach exists to fade a
        // screenshot running off the page, and the title page has no art to
        // fade; the dots and the button still get their ground either way.
        .background { scrim(m, reach: currentPageBleeds ? 170 : WelcomeMetrics.artClearance) }
    }

    /// What the art dissolves into at the foot of the page.
    ///
    /// Two layers, and they do different work. The **haze** is a material
    /// masked by a ramp, which is a progressive blur: what is behind it is
    /// genuinely softened, and softened more the further down it goes, so a
    /// screenshot full of small type stops competing with the button long
    /// before it reaches it. The **wash** is the ground's own colour over the
    /// top, which is what actually carries the last of it to opaque — blur
    /// alone leaves a blurred picture, not a page.
    ///
    /// Reduce Transparency drops the haze and leaves the wash, which is the
    /// same composition without the expensive half.
    @ViewBuilder
    private func scrim(_ m: WelcomeMetrics, reach: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            let opaque = m.scrimOpaque(reach: reach)

            if !reduceTransparency {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0), location: 0),
                                .init(color: .black.opacity(0.65), location: opaque * 0.45),
                                .init(color: .black, location: opaque * 0.8),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
            }

            // The wash's stops are fractions of `opaque` rather than of the
            // scrim, so lengthening the scrim lengthens the fade instead of
            // moving the line the dots are read against.
            LinearGradient(
                stops: [
                    .init(color: WelcomeInk.ground.opacity(0), location: 0),
                    .init(color: WelcomeInk.ground.opacity(0.30), location: opaque * 0.42),
                    .init(color: WelcomeInk.ground.opacity(0.80), location: opaque * 0.76),
                    .init(color: WelcomeInk.ground, location: opaque),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(height: m.scrimHeight(reach: reach))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// Six points, and the current one stretched to a capsule. A dot that only
    /// changes colour is hard to find at a glance; one that changes shape is not.
    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(pages) { item in
                let current = item.id == (page ?? 0)
                Capsule()
                    .fill(current
                          ? AnyShapeStyle(LinearGradient(colors: [Brand.ramp[1], Brand.ramp[3]],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(WelcomeInk.ink.opacity(0.20)))
                    .frame(width: current ? 18 : 6, height: WelcomeMetrics.dotsHeight)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: page)
        .accessibilityHidden(true)
    }

    private func advance(_ m: WelcomeMetrics) -> some View {
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
                // The reference's 320pt button on its 440pt page, as a share,
                // so the column and the button grow together.
                .frame(maxWidth: m.pageWidth * 320 / WelcomeMetrics.referenceWidth)
                .frame(height: WelcomeMetrics.buttonHeight)
                .background(
                    Capsule().fill(LinearGradient(colors: [Brand.ramp[1], Brand.ramp[2], Brand.ramp[3]],
                                                  startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Brand.ramp[3].opacity(0.30), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .accessibilityIdentifier("welcomeAdvance")
    }

    private var buttonTitle: String {
        guard (page ?? 0) == pages.count - 1 else {
            return isDevanagari ? "आगे" : "Next"
        }
        return isDevanagari ? "पढ़ना आरंभ करें" : "Begin reading"
    }

    /// Both ways out — the close button and "Begin reading" — end here.
    ///
    /// `pageTurn` rather than `panel`. Panel is the feel of the rail sliding,
    /// a medium impact at 0.7, and it is too slight to be felt through the
    /// gesture that ends the guide: several readers of this screen have
    /// reported no feedback at all on closing it. The guide handing over to the
    /// book is the same moment the splash hands over to it — `RootView` marks
    /// that with `pageTurn`, and this is the other door into the same room, so
    /// it gets the same feedback.
    private func finish() {
        Haptics.pageTurn()
        settings.hasSeenWelcome = true
        onFinish()
    }

    // MARK: - A page

    /// One page of the guide: words, art, and the ground they sit on.
    ///
    /// The page measures itself rather than asking the size class — see
    /// `WelcomeMetrics`. Everything below takes its sizes from that one value,
    /// so there is a single place where "this is the page we are on" is decided.
    @ViewBuilder
    private func page(_ item: WelcomePage, insets: EdgeInsets) -> some View {
        GeometryReader { proxy in
            let m = WelcomeMetrics(size: proxy.size,
                                   safeTop: insets.top,
                                   safeBottom: insets.bottom,
                                   devanagari: isDevanagari)

            content(item, m)
                .frame(width: m.content, alignment: .leading)
                // The column, centred in whatever the window actually is.
                // Past an iPad's width the page stops growing rather than
                // spreading — the same discipline `ReaderView` applies to the
                // verse itself — and it is centred rather than left in place,
                // so a resized Mac window never leaves the composition sitting
                // off to one side of its own ground.
                .frame(maxWidth: .infinity, alignment: .center)
                // A guard rather than a device: every measure is taken from
                // the page, so nothing should reach this.
                .clipped()
        }
        .accessibilityElement(children: .contain)
    }

    /// Words above art, on every page and every device.
    ///
    /// Three fixed points and one that gives. The words band starts at
    /// `topPadding` and is always `wordsHeight` tall, so the art begins on the
    /// same line whichever page is on screen; the controls own a strip of the
    /// foot; and the art is handed exactly what is left between them. The one
    /// thing that stretches is the art's own slot — which is the only place in
    /// the composition where a difference in screen height can be absorbed
    /// without moving something the eye is using as a datum.
    @ViewBuilder
    private func content(_ item: WelcomePage, _ m: WelcomeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if item.art == .opening {
                // The title page has no words band and no art slot: it is one
                // composition that owns everything above the controls.
                WelcomeOpening(isDevanagari: isDevanagari, metrics: m) {
                    settings.language = $0
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, m.topPadding)
                .padding(.bottom, m.controlsHeight)
            } else {
                // The fixed band. See `WelcomeMetrics.wordsHeight`: every page
                // spends the same height on its words whether it fills it or
                // not, so the rule, the kicker, the title and the art below
                // them all sit at the same height on every page.
                words(item, m)
                    .frame(width: m.content, height: m.wordsHeight, alignment: .topLeading)
                    .padding(.top, m.topPadding)
                    // Above the art, always. The art is the only thing on the
                    // page that is allowed to overrun its slot, and when it
                    // does it must pass *behind* the title, never over it.
                    .zIndex(1)

                Spacer(minLength: 0).frame(height: WelcomeMetrics.artGap)

                if item.isScreenshot {
                    // A screenshot is allowed to run off the foot of the page:
                    // that is what says the screen carries on past the edge,
                    // and the controls' scrim is already there to fade it out.
                    let slot = CGSize(width: m.content, height: m.artBleedHeight)
                    art(item, m, fitting: slot)
                        .frame(width: slot.width, height: slot.height, alignment: .top)
                        .clipped()
                        .zIndex(0)
                } else {
                    // Everything else is scaled to the slot rather than cut to
                    // it — cutting is what made the English card vanish outright
                    // on an SE. And the slot stops short of the wash: the art
                    // here is not meant to dissolve into anything, so a card
                    // whose last lines are under a fading scrim is just a card
                    // nobody can read.
                    let slot = CGSize(width: m.content,
                                      height: max(0, m.artHeight - WelcomeMetrics.artClearance))
                    FitToSlot(slot: slot) { art(item, m, fitting: slot) }
                        .zIndex(0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func words(_ item: WelcomePage, _ m: WelcomeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heading(item, m)
                .padding(.bottom, 12)

            Text(item.body(isDevanagari: isDevanagari))
                .font(bodyFont(m))
                .foregroundStyle(WelcomeInk.mute)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    /// The rule, the kicker and the title — everything above the body.
    ///
    /// Flows: rule, kicker, title, twelve points, body. The band that keeps
    /// the carousel steady is the whole words block, not this — reserving two
    /// lines of title *inside* the block opened a hole between a one-line title
    /// and its body on some pages and none on others, which is the opposite of
    /// a baseline.
    @ViewBuilder
    private func heading(_ item: WelcomePage, _ m: WelcomeMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(LinearGradient(colors: Brand.ramp, startPoint: .leading, endPoint: .trailing))
                .frame(width: 40, height: 3)
                .padding(.bottom, 20)

            Text(item.kicker(isDevanagari: isDevanagari))
                .font(kickerFont(m))
                // Tracking suits small-caps Latin and damages Devanagari, which
                // is already spaced by its own headline — the same rule
                // `PanelHeader` follows.
                .tracking(isDevanagari ? 0 : 3.4)
                .textCase(isDevanagari ? nil : .uppercase)
                .foregroundStyle(WelcomeInk.accent)
                .padding(.bottom, 12)

            Text(item.title(isDevanagari: isDevanagari))
                .font(titleFont(m))
                .foregroundStyle(WelcomeInk.ink)
                // Two lines and no more — the band is cut for two. Past that
                // the page has been given a title it is too narrow to carry,
                // and shrinking it is kinder than a four-line stack of two-word
                // fragments.
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    /// The middle belongs to the app itself.
    ///
    /// Wrapped in a `GeometryReader` so the art is told the size of the hole it
    /// is going into rather than inferring one from the page. That reading is
    /// what makes this responsive in the only sense that matters: the same code
    /// gives a 6.9" phone a tall narrow device, an SE a shorter one, and a
    /// resized Mac window whatever it currently deserves — without a single
    /// device check.
    @ViewBuilder
    /// The art, told the slot it is drawing into rather than measuring it.
    ///
    /// This used to read the slot with a `GeometryReader`, which cannot survive
    /// being put inside `FitToSlot`: fitting proposes an *unbounded* height so
    /// the content can state the height it wants, and a `GeometryReader` handed
    /// no height reports zero. The widgets, sized by `.aspectRatio(.fit)`
    /// against that zero, collapsed to a white pill. Every caller already knows
    /// the slot — it is computed from the metrics — so it is passed.
    private func art(_ item: WelcomePage, _ m: WelcomeMetrics,
                     fitting: CGSize) -> some View {
        Group {
            switch item.art {
            case .opening:
                EmptyView()
            case .verse:
                WelcomeVersePair(kind: .meaning, metrics: m, fitting: fitting)
            case .words:
                WelcomeVersePair(kind: .wordByWord, metrics: m, fitting: fitting)
            case .daily:
                WelcomeDaily(isDevanagari: isDevanagari, metrics: m, fitting: fitting)
            case .screen(let name):
                WelcomeVignette(art: name, isDevanagari: isDevanagari,
                                metrics: m, fitting: fitting)
            }
        }
        // Centred across the measure. A device shot is narrower than the
        // column, and left to itself it sits off to one side.
        .frame(width: fitting.width, alignment: .top)
    }

    // MARK: - Type

    private func kickerFont(_ m: WelcomeMetrics) -> Font {
        isDevanagari
            ? .custom(Fonts.devanagari, size: m.kickerSize + 1).weight(.medium)
            : .custom(Fonts.latin, size: m.kickerSize).weight(.bold)
    }

    private func titleFont(_ m: WelcomeMetrics) -> Font {
        isDevanagari
            ? .custom(Fonts.devanagari, size: m.titleSize + 2).weight(.medium)
            : .custom(Fonts.latin, size: m.titleSize).weight(.bold)
    }

    private func bodyFont(_ m: WelcomeMetrics) -> Font {
        isDevanagari
            ? .custom(Fonts.devanagari, size: m.bodySize + 1).weight(.light)
            : .custom(Fonts.latin, size: m.bodySize)
    }
}

// MARK: - Palette

/// The welcome's three ink colours and its ground.
///
/// The inks are `Theme.sepia`'s own `textPrimary`, `textSecondary` and
/// `accent`, lifted rather than invented — the welcome is the one screen that
/// is neither the reading surface nor the brand, and Sepia is where this app
/// already keeps warm type. The ground is a warm white rather than `.white`:
/// pure white under a warm serif reads cold, and the difference costs nothing.
enum WelcomeInk {
    static let ground = Color(.sRGB, red: 0xFD / 255, green: 0xFA / 255, blue: 0xF4 / 255, opacity: 1)
    static let ink    = Color(.sRGB, red: 0x35 / 255, green: 0x29 / 255, blue: 0x1A / 255, opacity: 1)
    static let mute   = Color(.sRGB, red: 0x6E / 255, green: 0x5C / 255, blue: 0x43 / 255, opacity: 1)
    static let accent = Color(.sRGB, red: 0xB4 / 255, green: 0x57 / 255, blue: 0x1A / 255, opacity: 1)
    static var hairline: Color { ink.opacity(0.13) }
    static var cardEdge: Color { ink.opacity(0.09) }
}

// MARK: - Content

/// What a page shows in its middle.
enum WelcomeArt: Equatable, Sendable {
    /// The title page: the name, the greeting, and the language choice.
    case opening
    /// The verse in both scripts: shloka, translation, meaning.
    case verse
    /// The same verse in both scripts, glossed word by word.
    case words
    /// A screenshot of the named screen, in a device frame.
    case screen(String)
    /// The reminder and the widgets, which are not screens.
    case daily
}

/// The nine pages, as content rather than as views.
///
/// Both languages on every page, like every other pair of strings in the app —
/// the face follows the script, and neither can be chosen without the other.
struct WelcomePage: Identifiable, Sendable {
    let id: Int
    let art: WelcomeArt
    let kickerSa: String
    let kickerEn: String
    let titleSa: String
    let titleEn: String
    let bodySa: String
    let bodyEn: String

    /// Whether the art is a capture of a screen, shown in a device frame.
    var isScreenshot: Bool {
        if case .screen = art { return true }
        return false
    }

    func kicker(isDevanagari: Bool) -> String { isDevanagari ? kickerSa : kickerEn }
    func title(isDevanagari: Bool) -> String { isDevanagari ? titleSa : titleEn }
    func body(isDevanagari: Bool) -> String { isDevanagari ? bodySa : bodyEn }

    static let all: [WelcomePage] = [
        WelcomePage(
            id: 0, art: .opening,
            kickerSa: "स्वागत", kickerEn: "Welcome",
            titleSa: "", titleEn: "", bodySa: "", bodyEn: ""
        ),
        WelcomePage(
            id: 1, art: .verse,
            kickerSa: "पाठ", kickerEn: "Reading",
            titleSa: "पूरा श्लोक", titleEn: "Every verse, in full",
            bodySa: "मूल श्लोक, अनुवाद और भावार्थ, एक ही पृष्ठ पर।",
            bodyEn: "Sanskrit, translation and meaning, together on one page."
        ),
        WelcomePage(
            id: 2, art: .words,
            kickerSa: "पाठ", kickerEn: "Reading",
            titleSa: "शब्दार्थ", titleEn: "Word by word",
            bodySa: "पढ़ते-पढ़ते, हर संस्कृत शब्द का अर्थ।",
            bodyEn: "Understand every Sanskrit word as you read."
        ),
        WelcomePage(
            id: 3, art: .screen("contents"),
            kickerSa: "पाठ", kickerEn: "Reading",
            titleSa: "जहाँ से चाहें, वहीं से", titleEn: "Find your place",
            bodySa: "सरकाकर पढ़ें, या सीधे किसी भी श्लोक पर जाएँ।",
            bodyEn: "Swipe through, or jump straight to any verse."
        ),
        WelcomePage(
            id: 4, art: .screen("appearance"),
            kickerSa: "पाठ", kickerEn: "Reading",
            titleSa: "आँखों को आराम", titleEn: "Made for your eyes",
            bodySa: "प्रकाश, अंधकार या सेपिया, अपने अक्षर-आकार में।",
            bodyEn: "Light, Dark or Sepia, at any text size."
        ),
        WelcomePage(
            id: 5, art: .screen("search"),
            kickerSa: "खोज", kickerEn: "Search",
            titleSa: "पूरी गीता में खोजें", titleEn: "Search the whole Gita",
            bodySa: "शब्द, अर्थ या संख्या से। तुरंत, बिना इंटरनेट।",
            bodyEn: "By word, meaning or number. Instant, and offline."
        ),
        WelcomePage(
            id: 6, art: .screen("bookmark"),
            kickerSa: "संग्रह", kickerEn: "Save",
            titleSa: "जो भाए, सहेज लें", titleEn: "Keep what speaks to you",
            bodySa: "श्लोक सहेजें, या चित्र बनाकर साझा करें।",
            bodyEn: "Save a verse, or share it as a card."
        ),
        WelcomePage(
            id: 7, art: .screen("progress"),
            kickerSa: "प्रगति", kickerEn: "Progress",
            titleSa: "अब तक की यात्रा", titleEn: "See how far you have come",
            bodySa: "पढ़ा हुआ अपने आप अंकित, और राह में पैंतीस लक्ष्य।",
            bodyEn: "Your reading marks itself, and thirty-five goals await."
        ),
        WelcomePage(
            id: 8, art: .daily,
            kickerSa: "प्रतिदिन", kickerEn: "Every day",
            titleSa: "प्रतिदिन एक श्लोक", titleEn: "A verse every day",
            bodySa: "एक स्मरण, और होम स्क्रीन पर विजेट।",
            bodyEn: "A daily reminder, and a widget for your Home Screen."
        ),
    ]
}
