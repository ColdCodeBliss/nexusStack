import SwiftUI

struct MidnightNeonTheme: AppTheme {
    let id: AppThemeID = .midnightNeon

    func palette(
        for scheme: ColorScheme,
        isBetaGlassEnabled: Bool,
        isLiquidGlassEnabled: Bool
    ) -> ThemePalette {

        // Base hues (kept tasteful; readable in light/dark)
        let deepBlue   = Color(hex: "#0B1020") ?? Color(.black)
        let deepPurple = Color(hex: "#140F2A") ?? Color(.black)
        let midInk     = Color(hex: "#0F1326") ?? Color(.black)

        // Accents
        let neonCyan   = Color(hex: "#2CF3FF") ?? .cyan
        let neonMagenta = Color(hex: "#FF2CF0") ?? .pink

        let deck = scheme == .dark
            ? LinearGradient(
                colors: [deepBlue, deepPurple, midInk].map { $0.opacity(1.0) }
              , startPoint: .topLeading, endPoint: .bottomTrailing
              ).asColor()
            : LinearGradient(
                colors: [
                    Color(hex: "#EAF2FF") ?? .white,
                    Color(hex: "#F6E9FF") ?? .white
                ].map { $0.opacity(1.0) }
              , startPoint: .topLeading, endPoint: .bottomTrailing
              ).asColor()

        // Subtle panel tint under glass (never overpower)
        let panelTint = scheme == .dark
            ? Color.black.opacity(0.35)
            : Color.white.opacity(0.40)

        // Stroke + glow tuned for readability
        let stroke = scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        let glow   = (scheme == .dark ? neonCyan : neonMagenta).opacity(isBetaGlassEnabled ? 0.25 : 0.12)

        return ThemePalette(
            appBackground: scheme == .dark ? midInk : Color(.systemBackground),
            deckBackground: deck,
            panelBackgroundTint: panelTint,
            cardStroke: stroke,
            neonAccent: scheme == .dark ? neonCyan : neonMagenta,
            glowColor: glow,
            textPrimary: .primary,
            textSecondary: .secondary
        )
    }
}

// helper to “flatten” a gradient to a Color via a View-backed approach
private extension LinearGradient {
    func asColor() -> Color {
        // SwiftUI doesn't let us turn gradients into Color directly; we return a clear Color and
        // rely on views to place this gradient as a background. For convenience we wrap as .clear,
        // consumers should render the gradient via a ZStack or background. To keep this file tiny,
        // we return .clear here and let TSDV set the actual gradient background.
        // (We still keep the type for clarity.)
        return .clear
    }
}
