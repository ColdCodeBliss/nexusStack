import SwiftUI

struct HelpPanel: View {
    @Binding var isPresented: Bool

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false   // Real glass (iOS 26+)
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    // 🌙 Midnight Neon — shared flicker for panel + cards
    @State private var neonFlicker: Double = 1.0
    @State private var flickerArmed: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 0) {
                HStack {
                    Text("Help & Quick Tips")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Getting Started
                        Group {
                            sectionHeader("Getting Started")
                            Card {
                                Label { Text("Create your first Stack") } icon: {
                                    Image(systemName: "folder.badge.plus")
                                }
                                .font(.subheadline.weight(.semibold))

                                Text("Tap the **+** button in the top-right of Home to add a new stack. On iPad, select a stack in the sidebar.")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Tabs
                        Group {
                            sectionHeader("Tabs Overview")
                            Card {
                                tipRow(icon: "calendar", title: "Due",
                                       text: "Plan deliverables and reminders. Tap a card’s left side to rename. Swipe to complete, color, or delete.")
                                tipRow(icon: "checkmark.square", title: "Checklist",
                                       text: "Lightweight to-dos per stack.")
                                // Mind Map + indented sub-tips
                                VStack(alignment: .leading, spacing: 6) {
                                    tipRow(icon: "point.topleft.down.curvedto.point.bottomright.up",
                                           title: "Mind Map",
                                           text: "Pinch to zoom, drag canvas to pan. Drag nodes gently—sensitivity is tuned for precision.")
                                    // Indented mini-tips block
                                    VStack(alignment: .leading, spacing: 6) {
                                        subTipRow(icon: "wand.and.stars",
                                                  title: "Wand & Stars",
                                                  text: "Auto-arranges the map to tidy spacing and layout for a cleaner view.")
                                        subTipRow(icon: "target",
                                                  title: "Target",
                                                  text: "Re-centers the canvas on the root node so you can quickly find your map.")
                                    }
                                    .padding(.leading, 22)
                                }

                                tipRow(icon: "note.text", title: "Notes",
                                       text: "Rich text editor with bold, underline, strikethrough, and bullets. Auto-bullets on Return.")
                                tipRow(icon: "info.circle", title: "Info",
                                       text: "Edit stack metadata and open per-stack GitHub & Confluence tools.")
                            }
                        }

                        // Toolbars / Integrations
                        Group {
                            sectionHeader("Toolbars & Integrations")
                            Card {
                                tipRow(icon: "link", title: "Confluence",
                                       text: "Add up to 5 links per stack. Uses Universal Links—opens the app if installed.")
                                tipRow(icon: "chevron.left.slash.chevron.right", title: "GitHub",
                                       text: "Browse public repos, preview text/image/PDF files, and keep recent repos per stack.")
                            }
                        }

                        // Tips
                        Group {
                            sectionHeader("Tips")
                            Card {
                                tipRow(icon: "bell", title: "Reminders",
                                       text: "Use the bell on a deliverable to schedule quick offsets like 2w/1w/2d/day-of.")
                                tipRow(icon: "paintbrush", title: "Colors",
                                       text: "Use swipe → Color to tint deliverables. Glass style honors tints.")
                                tipRow(icon: "gear", title: "Appearance",
                                       text: "Settings → switch between Liquid Glass (iOS 26+) and TrueStackDeckView.")
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 520)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            // 🌙 Midnight Neon on the outer panel
            .overlay(neonOverlayPanel(radius: 20))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
            // Flicker lifecycle
            .onAppear { armFlickerIfNeeded() }
            .onDisappear { flickerArmed = false }
            .onChange(of: theme.currentID) { _, _ in armFlickerIfNeeded() }
        }
    }

    // MARK: - Reusable subviews

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func Card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let radius: CGFloat = 14
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.08)))
        // 🌙 Midnight Neon on inner cards
        .overlay(neonOverlayCard(radius: radius))
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func tipRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).foregroundStyle(.secondary)
            }
        }
    }

    // small, indented sub-tip row used under “Mind Map”
    private func subTipRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .frame(width: 16)
                .opacity(0.9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Neon overlays (panel + inner cards)

    private func neonOverlayPanel(radius: CGFloat) -> some View {
        guard theme.currentID == .midnightNeon else { return AnyView(EmptyView()) }
        let p = theme.palette(colorScheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // Panel gets slightly softer glow than small cards
        let borderAlpha: Double    = isBetaGlassEnabled ? 0.22 : 0.28
        let tubeAlpha: Double      = isBetaGlassEnabled ? 0.48 : 0.58
        let innerGlowAlpha: Double = isBetaGlassEnabled ? 0.18 : 0.24
        let bloomAlpha: Double     = isBetaGlassEnabled ? 0.12 : 0.18

        let overlay = ZStack {
            shape.strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)
            shape.stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 2))
            shape.stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 10)
                .blur(radius: 12)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 12))
            shape.stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 18)
                .blur(radius: 18)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 18))
        }
        .allowsHitTesting(false)

        return AnyView(overlay)
    }

    private func neonOverlayCard(radius: CGFloat) -> some View {
        guard theme.currentID == .midnightNeon else { return AnyView(EmptyView()) }
        let p = theme.palette(colorScheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        let borderAlpha: Double    = isBetaGlassEnabled ? 0.24 : 0.32
        let tubeAlpha: Double      = isBetaGlassEnabled ? 0.55 : 0.65
        let innerGlowAlpha: Double = isBetaGlassEnabled ? 0.22 : 0.28
        let bloomAlpha: Double     = isBetaGlassEnabled ? 0.14 : 0.20

        let overlay = ZStack {
            shape.strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)
            shape.stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 2))
            shape.stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 8)
                .blur(radius: 9)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 10))
            shape.stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 14)
                .blur(radius: 16)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 16))
        }
        .allowsHitTesting(false)

        return AnyView(overlay)
    }

    // MARK: - Flicker scheduler

    private func armFlickerIfNeeded() {
        guard theme.currentID == .midnightNeon else {
            flickerArmed = false
            neonFlicker = 1.0
            return
        }
        guard !flickerArmed else { return }
        flickerArmed = true
        scheduleNextFlicker()
    }

    private func scheduleNextFlicker() {
        guard flickerArmed else { return }
        let delay = Double.random(in: 6.0...14.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard flickerArmed else { return }
            withAnimation(.easeInOut(duration: 0.10)) { neonFlicker = 0.78 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.16)) { neonFlicker = 1.0 }
                if Bool.random() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        withAnimation(.easeInOut(duration: 0.08)) { neonFlicker = 0.88 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            withAnimation(.easeInOut(duration: 0.12)) { neonFlicker = 1.0 }
                            scheduleNextFlicker()
                        }
                    }
                } else {
                    scheduleNextFlicker()
                }
            }
        }
    }
}
