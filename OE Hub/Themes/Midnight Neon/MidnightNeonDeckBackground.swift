//
//  MidnightNeonDeckBackground.swift
//  OE Hub
//
//  Created by Ryan Bliss on 11/12/25.
//


import SwiftUI

struct MidnightNeonDeckBackground: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var body: some View {
        let p = theme.palette(scheme)

        ZStack {
            // 1) Base gradient (dark = deep blues/purples; light = cool pastels)
            backgroundGradient

            // 2) Soft radial neon bloom from the center (very low opacity)
            RadialGradient(
                gradient: Gradient(colors: [
                    p.glowColor.opacity(scheme == .dark ? 0.18 : 0.10),
                    .clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 650
            )
            .blendMode(.plusLighter)

            // 3) Subtle vignette to focus content
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

            // 4) Optional “grid mist” – almost invisible, adds texture
            if scheme == .dark {
                Canvas { ctx, size in
                    let step: CGFloat = 44
                    var path = Path()
                    for x in stride(from: 0, through: size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    ctx.stroke(path,
                               with: .color(p.neonAccent.opacity(isBetaGlassEnabled ? 0.045 : 0.03)),
                               lineWidth: 0.5)
                }
                .blendMode(.plusLighter)
            }
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
