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
                    p.glowColor.opacity(scheme == .dark ? 0.20 : 0.14),
                    .clear
                ]),
                center: .center,
                startRadius: 60,
                endRadius: 900
            )
            .blendMode(.plusLighter)

            // 3) Gentle vignette
            LinearGradient(
                colors: [
                    Color.black.opacity(scheme == .dark ? 0.20 : 0.08),
                    .clear,
                    Color.black.opacity(scheme == .dark ? 0.24 : 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // 4) NEON GRID — boosted visibility
            Canvas { ctx, size in
                let isDark = (scheme == .dark)

                // Slightly denser pattern for readability
                let step: CGFloat = isDark ? 40 : 40

                var path = Path()
                for x in stride(from: 0, through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                // Visibility knobs (boosted)
                let gridOpacityDark  = isBetaGlassEnabled ? 0.11 : 0.095   // was ~0.045–0.065
                let gridOpacityLight = isBetaGlassEnabled ? 0.22 : 0.090  // was ~0.095 : 0.075
                let lineWidth: CGFloat = isDark ? 0.95 : 0.8               // thicker

                let base = p.neonAccent.opacity(isDark ? gridOpacityDark : gridOpacityLight)

                // Primary stroke
                ctx.stroke(path, with: .color(base), lineWidth: lineWidth)

                // Subtle halo pass in dark mode for extra pop
                if isDark {
                    ctx.addFilter(.blur(radius: 0.9))
                    ctx.stroke(path, with: .color(p.neonAccent.opacity(0.09)), lineWidth: 1.4)
                }
            }
            // Additive in dark so lines “light up” the background
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
                    Color(hex: "#0B1020") ?? .black,
                    Color(hex: "#140F2A") ?? .black,
                    Color(hex: "#0F1326") ?? .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(hex: "#EAF2FF") ?? .white,
                    Color(hex: "#F6E9FF") ?? .white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
