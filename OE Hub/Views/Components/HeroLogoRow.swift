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

    var body: some View {
        let p = theme.palette(colorScheme)
        HStack {
            Spacer()
            Image("nexusStack_logo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .accessibilityHidden(true)
                // Subtle neon glow when Midnight Neon is selected
                .shadow(
                    color: theme.currentID == .midnightNeon ? p.glowColor : .clear,
                    radius: 24, y: 0
                )
                // Optional: a tight accent halo for a bit more pop
                .shadow(
                    color: theme.currentID == .midnightNeon ? p.neonAccent.opacity(0.15) : .clear,
                    radius: 6, y: 0
                )
            Spacer()
                .allowsHitTesting(false)   // ← makes the overlay ignore touches
        }
        .padding(.vertical, 0)       // real top/bottom padding
        .padding(.horizontal, 0)    // align with nav margins
        .background(.clear)
    }
}

