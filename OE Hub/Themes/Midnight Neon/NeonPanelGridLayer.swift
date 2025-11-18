import SwiftUI

/// Reusable neon grid for card/panel-style surfaces when Midnight Neon is active.
/// This does NOT draw glass or materials – just the grid, clipped to the given radius.
struct NeonPanelGridLayer: View {
    enum Density {
        case panel         // normal panel / sheet
        case compactChip   // small chips (like Settings preview)
    }

    var cornerRadius: CGFloat
    var density: Density = .panel

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Only draw when Midnight Neon is active
        if theme.currentID == .midnightNeon {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            shape
                .fill(Color.clear)
                .background {
                    Canvas { ctx, size in
                        let isDark = (colorScheme == .dark)

                        // Density & spacing tuned by use case
                        let step: CGFloat
                        let baseOpacity: Double
                        let lineWidth: CGFloat

                        switch density {
                        case .panel:
                            step = isDark ? 28 : 26
                            baseOpacity = isDark ? 0.11 : 0.12
                            lineWidth = isDark ? 0.85 : 0.8
                        case .compactChip:
                            step = isDark ? 14 : 12
                            baseOpacity = isDark ? 0.10 : 0.11
                            lineWidth = isDark ? 0.75 : 0.7
                        }

                        var path = Path()
                        for x in stride(from: 0, through: size.width, by: step) {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0, through: size.height, by: step) {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }

                        let p = theme.palette(colorScheme)
                        ctx.stroke(
                            path,
                            with: .color(p.neonAccent.opacity(baseOpacity)),
                            lineWidth: lineWidth
                        )

                        // Subtle halo in dark mode for extra punch
                        if isDark {
                            ctx.addFilter(.blur(radius: 0.8))
                            ctx.stroke(
                                path,
                                with: .color(p.neonAccent.opacity(0.08)),
                                lineWidth: lineWidth + 0.4
                            )
                        }
                    }
                    .clipShape(shape)
                }
        }
    }
}
