//
//  Theme.swift
//  Gita
//

import SwiftUI

/// The four reading themes from specs.md section 9.1.
///
/// Sepia is a real theme, not a tint on light mode, so the palette cannot ride
/// on `ColorScheme` alone — it is resolved once and injected through the
/// environment, and every colour in the app is read from it by role.
enum Theme: String, Sendable {
    case light
    case sepia
    case dark


    static func resolved(for colorScheme: ColorScheme) -> Theme {
        colorScheme == .dark ? .dark : .light
    }

    // MARK: - Tokens
    //
    // Light and dark are plain: white or black ground, primary/secondary text,
    // and no tint anywhere. Sepia is the only theme that colours anything —
    // choosing System should look like a system app, not like a warm one.

    var background: Color {
        switch self {
        case .light: .white
        case .sepia: Color(hex: 0xF3E9D6)
        case .dark: .black
        }
    }

    var surface: Color {
        switch self {
        case .light: .white
        case .sepia: Color(hex: 0xFBF3E4)
        case .dark: Color(hex: 0x1C1C1E)
        }
    }

    /// Black on light, white on dark — `.primary` follows the color scheme,
    /// which `preferredColorScheme` has already pinned to match the theme.
    var textPrimary: Color {
        switch self {
        case .light, .dark: .primary
        case .sepia: Color(hex: 0x35291A)
        }
    }

    var textSecondary: Color {
        switch self {
        case .light, .dark: .secondary
        case .sepia: Color(hex: 0x6E5C43)
        }
    }

    /// The colour of controls. Monochrome outside Sepia: a "System" theme that
    /// tinted everything saffron was the whole problem.
    var accent: Color {
        switch self {
        case .light, .dark: .primary
        case .sepia: Color(hex: 0xB4571A)
        }
    }

    var divider: Color {
        switch self {
        case .light, .dark: Color.secondary.opacity(0.25)
        case .sepia: Color(hex: 0x35291A).opacity(0.15)
        }
    }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = .light
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
