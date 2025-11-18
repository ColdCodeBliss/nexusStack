import SwiftUI

// MARK: - Manager

@MainActor
final class WhatsNewManager: ObservableObject {

    /// Controls whether the overlay should be visible.
    @Published var shouldShowWhatsNew: Bool = false

    /// Persist the last version for which the user has seen "What's New".
    @AppStorage("lastSeenWhatsNewVersion")
    private var lastSeenWhatsNewVersion: String = ""

    /// Minimum app version that should trigger the sheet.
    /// Adjust this if you want to change when it starts appearing.
    private let minVersionToShow = "1.0.5"

    /// Call this once on launch (e.g., from `HomeView.onAppear`).
    func handleLaunch() {
        let current = currentVersion
        guard !current.isEmpty else { return }

        // Only show for versions >= 1.0.5
        guard isAtLeast(current, comparedTo: minVersionToShow) else { return }

        // Only show if the user hasn't seen this version yet
        guard lastSeenWhatsNewVersion != current else { return }

        shouldShowWhatsNew = true
    }

    /// Call when the user dismisses the overlay (Got it / Explore themes).
    func markSeen() {
        let current = currentVersion
        guard !current.isEmpty else {
            shouldShowWhatsNew = false
            return
        }
        lastSeenWhatsNewVersion = current
        shouldShowWhatsNew = false
    }

    // MARK: - Version helpers

    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    /// Basic semantic comparison: returns true if `version` >= `min`.
    private func isAtLeast(_ version: String, comparedTo min: String) -> Bool {
        func components(_ v: String) -> [Int] {
            v.split(separator: ".").map { Int($0) ?? 0 }
        }
        let lhs = components(version)
        let rhs = components(min)
        let count = max(lhs.count, rhs.count)

        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return true // equal
    }
}

// MARK: - Overlay

struct WhatsNewPanel: View {
    @Binding var isPresented: Bool
    /// Called when the user taps "Explore Midnight Neon Theme".
    var onExploreThemes: () -> Void

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.60

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                }

            panel
                .padding(24)
                .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9),
                   value: isPresented)
    }

    // MARK: - Panel

    private var panel: some View {
        let p = theme.palette(colorScheme)
        let isNeon = (theme.currentID == .midnightNeon)

        return VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(alignment: .leading, spacing: 12) {
                Text("Midnight Neon Theme")
                    .font(.headline.weight(.semibold))

                Text("Dial your stacks into a glowing, grid-driven workspace. Midnight Neon adds:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                bulletRow(
                    icon: "sparkles",
                    text: "Neon tube borders and soft glow around stacks, tabs, and panels."
                )
                bulletRow(
                    icon: "square.grid.3x3.fill",
                    text: "Retro neon grid backgrounds across Home, True Stack, and detail tabs."
                )
                bulletRow(
                    icon: "wand.and.rays",
                    text: "Subtle flicker and glow tuned for focus—never overpowering."
                )
            }

            Divider().opacity(0.35)

            Text("You can enable the Midnight Neon theme from Settings → Themes. If it’s locked, you can unlock it as a one-time in-app purchase.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    // Open Settings / Themes
                    onExploreThemes()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                } label: {
                    Text("Explore Midnight Neon Theme")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(primaryButtonBackground)
                .clipShape(Capsule())

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(panelBackground)
        .overlay(neonBorderOverlay)
        .shadow(color: isNeon ? p.glowColor.opacity(0.45) : .black.opacity(0.35),
                radius: isNeon ? 24 : 18,
                x: 0, y: 0)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text("What’s New in .nexusStack")
                    .font(.title3.weight(.semibold))
                Text("v\(currentVersionText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(Color.secondary.opacity(0.16))
            )
        }
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Backgrounds / Borders

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                NeonPanelGridLayer(cornerRadius: 22, density: .panel)
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
        } else {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemBackground))
        }
    }

    private var neonBorderOverlay: some View {
        let p = theme.palette(colorScheme)
        let isNeon = (theme.currentID == .midnightNeon)

        return RoundedRectangle(cornerRadius: 22)
            .strokeBorder(
                isNeon ? p.neonAccent.opacity(0.95) : Color.primary.opacity(0.08),
                lineWidth: isNeon ? 2.0 : 1.0
            )
            .shadow(color: isNeon ? p.neonAccent.opacity(0.45) : .clear,
                    radius: isNeon ? 12 : 0,
                    x: 0, y: 0)
            .shadow(color: isNeon ? p.glowColor.opacity(0.55) : .clear,
                    radius: isNeon ? 22 : 0,
                    x: 0, y: 0)
    }

    @ViewBuilder
    private var primaryButtonBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .white.opacity(betaWhiteGlowOpacity),
                        radius: 10, x: 0, y: 0)
        } else {
            Capsule()
                .fill(Color.blue.opacity(0.88))
        }
    }

    private var currentVersionText: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.5"
    }
}
