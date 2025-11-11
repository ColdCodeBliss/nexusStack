import SwiftUI
import SwiftData

struct JobRowView: View {
    let job: Job

    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.22
    @EnvironmentObject private var theme: ThemeManager

    private let radius: CGFloat = 20

    // ─────────────── FLICKER: state and scheduling (no DispatchWorkItem) ───────────────
    @State private var neonFlicker: Double = 1.0     // 1.0 = full bright (default)
    @State private var isFlickerActive = false       // gates all scheduled steps

    private func scheduleNextFlicker() {
        guard theme.currentID == .midnightNeon, isFlickerActive else { return }
        let delay = Double.random(in: 6.0...14.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            runFlickerSequence()
        }
    }

    private func runFlickerSequence() {
        guard theme.currentID == .midnightNeon, isFlickerActive else { return }
        var t: TimeInterval = 0

        func step(_ value: Double, _ dur: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                guard isFlickerActive, theme.currentID == .midnightNeon else { return }
                withAnimation(.easeOut(duration: dur)) { neonFlicker = value }
            }
            t += dur + 0.02
        }

        // Short, gentle hiccup
        step(0.65, 0.06)
        step(1.00, 0.08)
        step(0.80, 0.04)
        step(1.00, 0.12)

        DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.4) {
            scheduleNextFlicker()
        }
    }
    // ─────────────── end FLICKER block ───────────────


    var body: some View {
        let tint = color(for: job.effectiveColorIndex)
        let p = theme.palette(colorScheme)

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
        .background(cardBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )

        // ✨ Midnight Neon (same layers as before) + FLICKER applied to tube & tight glow
        .overlay(alignment: .topLeading) {
            if theme.currentID == .midnightNeon {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

                // 0) Subtle inset border (inside bounds)
                shape
                    .strokeBorder(p.neonAccent.opacity(isBetaGlassEnabled ? 0.24 : 0.32), lineWidth: 1)

                // 1) "Tube" core — bright on the edge  ⟵ FLICKER multiplier
                shape
                    .stroke(p.neonAccent.opacity(0.95 * neonFlicker), lineWidth: 2)

                // 2) Tight inner glow — ring-masked + clipped  ⟵ FLICKER multiplier
                shape
                    .stroke(p.neonAccent.opacity(0.55 * neonFlicker), lineWidth: 8)
                    .blur(radius: 6)
                    .mask(
                        shape
                            .inset(by: 8 / 2)
                            .stroke(lineWidth: 8)
                    )
                    .compositingGroup()
                    .clipShape(shape)

                // 3) Inner bloom — wider, softer (kept constant for comfort)
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

                // 4) Misty OUTER glow with card color (unchanged)
                let glowColor = tint
                shape
                    .stroke(glowColor.opacity(0.15), lineWidth: 10)
                    .shadow(color: glowColor.opacity(0.28), radius: 10,  x: 0, y: 0)
                    .shadow(color: glowColor.opacity(0.20), radius: 18, x: 0, y: 0)
                    .shadow(color: glowColor.opacity(0.12), radius: 30, x: 0, y: 0)
                    .blendMode(.plusLighter)
            }
        }

        // Original shadow
        .shadow(color: currentShadowColor, radius: shadowRadius, y: shadowY)

        .padding(.vertical, 2)

        // ─────────────── FLICKER: lifecycle ───────────────
        .onAppear {
            isFlickerActive = (theme.currentID == .midnightNeon)
            if isFlickerActive { scheduleNextFlicker() }
        }
        .onDisappear {
            isFlickerActive = false
            neonFlicker = 1.0
        }
        .onChange(of: theme.currentID) {
            isFlickerActive = (theme.currentID == .midnightNeon)
            neonFlicker = 1.0
            if isFlickerActive { scheduleNextFlicker() }
        }
        // ─────────────── end FLICKER lifecycle ───────────────

    }

    // MARK: - Backgrounds

    @ViewBuilder
    private func cardBackground(tint: Color) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular.tint(tint.opacity(0.65)),
                        in: .rect(cornerRadius: radius)
                    )
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
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint)
        }
    }

    private var borderColor: Color {
        (isBetaGlassEnabled) ? .white.opacity(0.10) : .black.opacity(0.06)
    }

    private var currentShadowColor: Color {
        if isBetaGlassEnabled && colorScheme == .dark {
            let clamped = max(0.0, min(betaWhiteGlowOpacity, 1.0))
            return Color.white.opacity(clamped)
        }
        return (isBetaGlassEnabled) ? Color.black.opacity(0.25) : Color.black.opacity(0.15)
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
