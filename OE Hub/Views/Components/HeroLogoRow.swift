//
//  HeroLogoRow.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//

import SwiftUI

struct HeroLogoRow: View {
    var height: CGFloat = 80

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    // If the neon art appears larger due to glow/padding, scale it slightly.
    // Tweak this between ~0.84 ... 0.95 to visually match the standard logo.
    private let neonScaleComp: CGFloat = 0.58

    private var isNeon: Bool {
        theme.currentID == .midnightNeon
    }

    private var logoName: String {
        isNeon ? "nexusStack_logo_neon_b" : "nexusStack_logo"
    }

    var body: some View {
        let p = theme.palette(colorScheme)

        HStack {
            Spacer()
            Image(logoName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: height)                     // same height across themes
                .scaleEffect(isNeon ? neonScaleComp : 1)   // compensate neon’s perceived size
                .accessibilityHidden(true)
                // Smooth crossfade on theme switch
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: theme.currentID)
                // Subtle glow only when Neon is active
                .shadow(color: isNeon ? p.glowColor : .clear, radius: 24, y: 0)
                .shadow(color: isNeon ? p.neonAccent.opacity(0.15) : .clear, radius: 6, y: 0)
            Spacer()
                .allowsHitTesting(false)
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 0)
        .background(.clear)
    }
}
