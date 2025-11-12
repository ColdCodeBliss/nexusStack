import SwiftUI

struct MidnightNeonDeckBackground: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var body: some View {
        let p = theme.palette(scheme)

        ZStack {
            // 1) Base gradient by mode
            backgroundGradient

            // 2) Soft center bloom (a little stronger in dark)
            RadialGradient(
                gradient: Gradient(colors: [
                    p.glowColor.opacity(scheme == .dark ? 0.18 : 0.12),
                    .clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 650
            )
            .blendMode(.plusLighter)

            // 3) Gentle vignette
            LinearGradient(
                colors: [
                    Color.black.opacity(scheme == .dark ? 0.18 : 0.06),
                    .clear,
                    Color.black.opacity(scheme == .dark ? 0.22 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // 4) Neon grid — now visible in BOTH light and dark modes
            Canvas { ctx, size in
                let step: CGFloat = (scheme == .dark) ? 44 : 40
                var path = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                // Slightly stronger in light mode so it’s discernible on bright backgrounds.
                let gridOpacityDark  = isBetaGlassEnabled ? 0.045 : 0.030
                let gridOpacityLight = isBetaGlassEnabled ? 0.085 : 0.065
                let lineWidth: CGFloat = (scheme == .dark) ? 0.5 : 0.7

                let color = p.neonAccent.opacity(
                    scheme == .dark ? gridOpacityDark : gridOpacityLight
                )

                ctx.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
            // In dark mode we keep the additive look; in light mode we render normally
            .blendMode(scheme == .dark ? .plusLighter : .normal)
        }
        .ignoresSafeArea()
    }

    // MARK: - Gradient per mode
    @ViewBuilder
    private var backgroundGradient: some View {
        if scheme == .dark {
            LinearGradient(
                colors: [
                    Color(hex: "#0B1020") ?? .black,   // deepBlue
                    Color(hex: "#140F2A") ?? .black,   // deepPurple
                    Color(hex: "#0F1326") ?? .black    // midInk
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(hex: "#EAF2FF") ?? .white,   // cool white-blue
                    Color(hex: "#F6E9FF") ?? .white    // pale lavender
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
