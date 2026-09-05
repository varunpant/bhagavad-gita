//
//  WelcomeArtAssetTests.swift
//  GitaTests
//

import Foundation
import Testing

@testable import Gita

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// The welcome's screenshot pages come out of the asset catalogue, and the one
/// way they fail is silently: a name that resolves to nothing draws nothing,
/// and a guide page with no picture still lays out perfectly.
///
/// That is exactly what shipped. `make_welcome_art.py` wrote every imageset as
/// **`3x` only**, which every phone resolves and no Mac can: macOS displays are
/// 1x or 2x, so the pages came up blank in the Mac build while being right on
/// every simulator anyone had looked at. Nothing failed — there was simply
/// nothing there.
///
/// So two things are pinned here. That every name the welcome asks for resolves
/// to a real image **on the platform running the test**, which is what catches
/// the Mac case when the suite is run on macOS as `app/CLAUDE.md` asks. And
/// that the catalogue entries stay scale-agnostic, which is what makes the
/// first true.
@Suite("Welcome art assets")
@MainActor
struct WelcomeArtAssetTests {

    /// Every screenshot page, in both scripts — read off `WelcomePage.all`
    /// rather than listed again, so a tenth page cannot be added without this
    /// suite noticing.
    /// The app's own list, not a second copy of the naming rule — otherwise
    /// this suite passes while the app asks for something else entirely.
    private var assetNames: [String] { WelcomeArtStore.allNames }

    @Test("The welcome asks for screenshot pages at all")
    func thereAreScreenshotPages() {
        // A guard on the guard: if `WelcomeArt` ever stops using `.screen`,
        // every other test here passes by having nothing to check.
        #expect(assetNames.count >= 8, "found \(assetNames.count) screenshot assets")
    }

    @Test("Every welcome screenshot resolves on this platform")
    func everyAssetResolves() {
        var missing: [String] = []
        for name in assetNames where !imageExists(name) {
            missing.append(name)
        }
        let named = missing.joined(separator: ", ")
        #expect(missing.isEmpty,
                "no image for \(named) — on macOS that is usually an imageset declared 3x only")
    }

    @Test("Every welcome screenshot has a usable size")
    func everyAssetHasSize() {
        for name in assetNames {
            let size = imageSize(name)
            #expect(size.width > 0 && size.height > 0, "\(name) resolved to an empty image")
            // Portrait phone captures. A landscape one here means a shot was
            // taken on the wrong device, which the eye would not catch in a
            // 190pt-wide vignette.
            #expect(size.height > size.width, "\(name) is not a portrait capture")
        }
    }

    /// The catalogue entries must stay scale-agnostic.
    ///
    /// Read from the source catalogue rather than the built bundle: this is a
    /// rule about what `make_welcome_art.py` writes, and the failure it guards
    /// against is a future edit to that script.
    @Test("No welcome imageset pins itself to a scale")
    func noImagesetDeclaresAScale() throws {
        let catalogue = try #require(Self.assetCatalogue, "Assets.xcassets not found from \(#filePath)")

        for name in assetNames {
            let contents = catalogue
                .appendingPathComponent("\(name).imageset")
                .appendingPathComponent("Contents.json")
            let data = try #require(try? Data(contentsOf: contents), "no Contents.json for \(name)")
            let json = try #require(
                try JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            let images = try #require(json["images"] as? [[String: Any]])

            #expect(!images.isEmpty, "\(name) declares no image")
            for image in images {
                #expect(image["scale"] == nil,
                        "\(name) pins a scale, and a Mac has no 3x display: a scaled-only imageset draws nothing")
            }
        }
    }

    // MARK: - Platform

    private func imageExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #else
        NSImage(named: name) != nil
        #endif
    }

    private func imageSize(_ name: String) -> CGSize {
        #if canImport(UIKit)
        UIImage(named: name)?.size ?? .zero
        #else
        NSImage(named: name)?.size ?? .zero
        #endif
    }

    /// `.../app/Gita/GitaTests/WelcomeArtAssetTests.swift` → `.../Gita/Assets.xcassets`
    ///
    /// `#filePath` is resolved at compile time, so the test knows where its own
    /// source lives even when running from a bundle somewhere else entirely —
    /// the same trick `ScreenshotUITests` uses to write into the repository.
    private static let assetCatalogue: URL? = {
        let catalogue = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // GitaTests
            .deletingLastPathComponent()      // Gita
            .appendingPathComponent("Gita/Assets.xcassets", isDirectory: true)
        return FileManager.default.fileExists(atPath: catalogue.path) ? catalogue : nil
    }()
}
