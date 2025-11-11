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

        // NEW: Midnight Neon accent border (adds on top of original)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    theme.currentID == .midnightNeon
                    ? p.neonAccent.opacity(isBetaGlassEnabled ? 0.28 : 0.35)
                    : .clear,
                    lineWidth: 1
                )
        )


        // Original floating bubble shadow (kept)
        .shadow(color: currentShadowColor, radius: shadowRadius, y: shadowY)

        // NEW: Neon glow (separate shadow so it layers with the existing one)
        .shadow(
            color: theme.currentID == .midnightNeon ? p.glowColor : .clear,
            radius: isBetaGlassEnabled ? 10 : 14,
            y: 0
        )

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
