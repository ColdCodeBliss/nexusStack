//
//  AppThemeID.swift
//  OE Hub
//
//  Created by Ryan Bliss on 11/9/25.
//


import SwiftUI

// MARK: - IDs

enum AppThemeID: String, CaseIterable, Identifiable {
    case system       // current look (status quo)
    case midnightNeon // first premium theme

    var id: String { rawValue }
}

// MARK: - Palette (semantic tokens, tiny & expandable)

struct ThemePalette {
    // Surfaces
    var appBackground: Color          // global app bg
    var deckBackground: Color         // TSDV backdrop
    var panelBackgroundTint: Color    // TSEV tint under glass

    // Accents / strokes / glow
    var cardStroke: Color
    var neonAccent: Color
    var glowColor: Color

    // Text
    var textPrimary: Color
    var textSecondary: Color
}

// MARK: - Theme protocol

protocol AppTheme {
    var id: AppThemeID { get }
    func palette(
        for scheme: ColorScheme,
        isBetaGlassEnabled: Bool,
        isLiquidGlassEnabled: Bool
    ) -> ThemePalette
}

// MARK: - Built-in "System" (no-op) theme

struct SystemTheme: AppTheme {
    let id: AppThemeID = .system

    func palette(
        for scheme: ColorScheme,
        isBetaGlassEnabled: Bool,
        isLiquidGlassEnabled: Bool
    ) -> ThemePalette {
        ThemePalette(
            appBackground: Color(.systemBackground),
            deckBackground: Color(.systemBackground),
            panelBackgroundTint: scheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.35),
            cardStroke: scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.06),
            neonAccent: .accentColor,
            glowColor: .clear,
            textPrimary: .primary,
            textSecondary: .secondary
        )
    }
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("selectedThemeID") private var selectedThemeIDRaw: String = AppThemeID.system.rawValue
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false

    // register themes here
    private let registry: [AppThemeID: AppTheme] = [
        .system: SystemTheme(),
        .midnightNeon: MidnightNeonTheme()
    ]

        // Derive from AppStorage (no init-time read)
        var currentID: AppThemeID {
            AppThemeID(rawValue: selectedThemeIDRaw) ?? .system
        }

    func select(_ id: AppThemeID) {
        selectedThemeIDRaw = id.rawValue
        objectWillChange.send()
    }

    func palette(_ scheme: ColorScheme) -> ThemePalette {
        let theme = registry[currentID] ?? SystemTheme()
        return theme.palette(
            for: scheme,
            isBetaGlassEnabled: isBetaGlassEnabled,
            isLiquidGlassEnabled: isLiquidGlassEnabled
        )
    }
}
