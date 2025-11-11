import SwiftUI
import SwiftData

struct JobRowView: View {
    let job: Job

    // Beta (real Liquid Glass) toggle
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @Environment(\.colorScheme) private var colorScheme

    // 🔧 Slider-driven white glow intensity (set this from SettingsPanel)
    // Suggested slider range: 0.00 ... 0.60
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.22

    // THEME (added)
    @EnvironmentObject private var theme: ThemeManager

    private let radius: CGFloat = 20

    var body: some View {
        let tint = color(for: job.effectiveColorIndex)
        let p = theme.palette(colorScheme) // theme palette for neon/glow

        VStack(alignment: .leading, spacing: 8) {
            Text(job.title)
                .font(.headline)

            Text("Created: \(job.creationDate, format: .dateTime.day().month().year())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(activeItemsCount(job)) active items")
                .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(tint: tint))                     // ← bubble styles here
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        // Original border (kept)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )

        // ✨ Midnight Neon aesthetic (layered, exact-fit; no layout changes)
        .overlay(alignment: .topLeading) {
            if theme.currentID == .midnightNeon {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

                // 0) Subtle inset border (inside bounds)
                shape
                    .strokeBorder(p.neonAccent.opacity(isBetaGlassEnabled ? 0.24 : 0.32), lineWidth: 1)

                // 1) "Tube" core — bright on the edge
                shape
                    .stroke(p.neonAccent.opacity(0.95), lineWidth: 2)

                // 2) Tight inner glow — ring-masked + clipped to the row shape
                shape
                    .stroke(p.neonAccent.opacity(0.55), lineWidth: 8)
                    .blur(radius: 6)
                    .mask(
                        shape
                            .inset(by: 8 / 2)
                            .stroke(lineWidth: 8)
                    )
                    .compositingGroup()
                    .clipShape(shape)

                // 3) Inner bloom — wider, softer wash (still clipped)
                shape
                    .stroke(p.neonAccent.opacity(0.28), lineWidth: 18)
                    .blur(radius: 18)
                    .mask(
                        shape
                            .inset(by: 18 / 2)
                            .stroke(lineWidth: 18)
                    )
                    .compositingGroup()
                    .clipShape(shape)

                // 4) Misty OUTER glow around the rim — uses the card color
                let glowColor = tint
                shape
                    .stroke(glowColor.opacity(0.15), lineWidth: 10)     // faint geometry for shadow mask
                    .shadow(color: glowColor.opacity(0.28), radius: 10,  x: 0, y: 0) // tight aura
                    .shadow(color: glowColor.opacity(0.20), radius: 18, x: 0, y: 0) // mid bloom
                    .shadow(color: glowColor.opacity(0.12), radius: 30, x: 0, y: 0) // wide feather
                    .blendMode(.plusLighter)
            }
        }

        // Original floating bubble shadow (kept)
        .shadow(color: currentShadowColor, radius: shadowRadius, y: shadowY)

        // (Removed the previous neon .shadow block; replaced by overlay above.)

        .padding(.vertical, 2)
    }

    // MARK: - Backgrounds (Beta → real Liquid Glass; else solid)

    @ViewBuilder
    private func cardBackground(tint: Color) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            // ✅ Real Liquid Glass (iOS 26+)
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular.tint(tint.opacity(0.65)),
                        in: .rect(cornerRadius: radius)
                    )
                // soft highlight for depth (keeps “bubble” vibe)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), .clear],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            // 🎨 Original solid/tinted look
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint)
        }
    }

    private var borderColor: Color {
        (isBetaGlassEnabled)
        ? .white.opacity(0.10)
        : .black.opacity(0.06)
    }

    // 🔥 White glow only in Dark Mode + Beta; otherwise your previous shadows
    private var currentShadowColor: Color {
        if isBetaGlassEnabled && colorScheme == .dark {
            let clamped = max(0.0, min(betaWhiteGlowOpacity, 1.0)) // safety clamp
            return Color.white.opacity(clamped)
        }
        return (isBetaGlassEnabled)
            ? Color.black.opacity(0.25)
            : Color.black.opacity(0.15)
    }

    private var shadowRadius: CGFloat { (isBetaGlassEnabled) ? 14 : 5 }
    private var shadowY: CGFloat { (isBetaGlassEnabled) ? 8 : 0 }

    // MARK: - Helpers

    private func activeItemsCount(_ job: Job) -> Int {
        let activeDeliverables = job.deliverables.filter { !$0.isCompleted }.count
        let activeChecklistItems = job.checklistItems.filter { !$0.isCompleted }.count
        return activeDeliverables + activeChecklistItems
    }
}
