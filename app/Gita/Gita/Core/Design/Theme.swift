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
enum Theme: String, CaseIterable, Identifiable, Sendable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    static func resolved(for colorScheme: ColorScheme) -> Theme {
        colorScheme == .dark ? .dark : .light
    }

    // MARK: - Tokens

    var background: Color {
        switch self {
        case .light: Color(hex: 0xFBF9F4)
        case .sepia: Color(hex: 0xF3E9D6)
        case .dark: Color(hex: 0x14110E)
        }
    }

    var surface: Color {
        switch self {
        case .light: Color(hex: 0xFFFFFF)
        case .sepia: Color(hex: 0xFBF3E4)
        case .dark: Color(hex: 0x1E1A16)
        }
    }

    var textPrimary: Color {
        switch self {
        case .light: Color(hex: 0x211D18)
        case .sepia: Color(hex: 0x35291A)
        case .dark: Color(hex: 0xECE6DA)
        }
    }

    var textSecondary: Color {
        switch self {
        case .light: Color(hex: 0x6B6155)
        case .sepia: Color(hex: 0x6E5C43)
        case .dark: Color(hex: 0xA79E90)
        }
    }

    /// Saffron. Used sparingly — active states and the progress rail. Never a
    /// fill behind text.
    var accent: Color {
        switch self {
        case .light: Color(hex: 0xC8611C)
        case .sepia: Color(hex: 0xB4571A)
        case .dark: Color(hex: 0xE6873C)
        }
    }

    var divider: Color {
        switch self {
        case .light: textPrimary.opacity(0.08)
        case .sepia: textPrimary.opacity(0.10)
        case .dark: textPrimary.opacity(0.12)
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
