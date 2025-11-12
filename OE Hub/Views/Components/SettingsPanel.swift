import SwiftUI
import StoreKit

struct SettingsPanel: View {
    @Binding var isPresented: Bool

    // Appearance flags
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real glass (iOS 26+)
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.60
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false

    // Stores
    @StateObject private var store = DonationStore()       // Donations (existing)
    @StateObject private var themeStore = ThemeStore()     // Themes (new)

    // Theme manager
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    // 🌙 Midnight Neon flicker (shared across panel + cards)
    @State private var neonFlicker: Double = 1.0
    @State private var flickerArmed: Bool = false
    

    var body: some View {
        ZStack {
            dimmedBackdrop
            panelContainer
        }
    }

    // MARK: - Backdrop

    private var dimmedBackdrop: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .onTapGesture { isPresented = false }
    }

    // MARK: - Panel container

    private var panelContainer: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView { contentStack.padding(16) }
        }
        .frame(maxWidth: 520)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
        .overlay { neonOverlayPanel(radius: 20) }     // ← Neon on outer panel
        .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
        .padding(.horizontal, 16)
        .transition(.scale.combined(with: .opacity))
        .task {
            await store.load()
            await themeStore.load()
        }
        .overlay(alignment: .bottom) { bottomToast }
        .onAppear { armFlickerIfNeeded() }
        .onDisappear { flickerArmed = false }
        .onChange(of: theme.currentID) { _, _ in armFlickerIfNeeded() }
    }

    private var header: some View {
        HStack {
            Text("Settings").font(.headline)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var bottomToast: some View {
        Group {
            if let msg = themeStore.lastMessage {
                Text(msg)
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Content stack

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearanceSection
            themesSection
            supportSection
            aboutSection
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Dark Mode", isOn: $isDarkMode)

                if #available(iOS 26.0, *) {
                    Toggle("Liquid Glass (Beta, iOS 26+)", isOn: $isBetaGlassEnabled)
                } else {
                    Toggle("Liquid Glass (Beta, iOS 26+)", isOn: .constant(false))
                        .disabled(true)
                        .foregroundStyle(.secondary)
                }

                if #available(iOS 26.0, *), isBetaGlassEnabled {
                    glowIntensityControls
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if #available(iOS 26.0, *), isBetaGlassEnabled {
                    Toggle("True Stack (Card Deck UI)", isOn: $isTrueStackEnabled)
                        .tint(.blue)
                }
            }
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
            .overlay { neonOverlayCard(radius: 14) }  // ← Neon on inner card
            .animation(.default, value: isBetaGlassEnabled)
        }
    }

    private var glowIntensityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Glow intensity")
                Spacer()
                Text("\(Int(betaWhiteGlowOpacity * 100))%")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $betaWhiteGlowOpacity, in: 0.0...1.0, step: 0.05)
                .accessibilityLabel("Glow intensity")
            Text("Controls highlight/shine strength for Liquid Glass surfaces.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Themes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                // System (free)
                HStack {
                    Label("System (default)", systemImage: theme.currentID == .system ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.titleAndIcon)
                    Spacer()
                    Button("Use") { theme.select(.system) }
                        .buttonStyle(.bordered)
                }
                .accessibilityElement(children: .combine)

                // Midnight Neon (IAP)
                neonRow

                // Tiny preview chip (non-invasive)
                ThemePreviewRow(isNeon: true)
                    .frame(height: 36)
                    .opacity(0.9)

                // DEBUG-ONLY: Activate without purchase for screenshots
                #if DEBUG
                HStack {
                    Button("Activate (Test)") {
                        theme.select(.midnightNeon)
                        themeStore.lastMessage = "Midnight Neon activated for testing."
                    }
                    .buttonStyle(.bordered)

                    Button("Revert to System") {
                        theme.select(.system)
                        themeStore.lastMessage = "Reverted to System theme."
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .font(.footnote)
                .opacity(0.9)
                #endif

                HStack {
                    Button("Restore Purchases") {
                        Task { await themeStore.restorePurchases() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
            .overlay { neonOverlayCard(radius: 14) }  // ← Neon on inner card
        }
    }

    private var neonRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: theme.currentID == .midnightNeon ? "checkmark.circle.fill" : "circle")
                    Text("Midnight Neon")
                    if !themeStore.isMidnightNeonUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Locked")
                    }
                }
                Spacer()
                if themeStore.isMidnightNeonUnlocked {
                    Button("Use") { theme.select(.midnightNeon) }
                        .buttonStyle(.borderedProminent)
                } else {
                    let price = themeStore.midnightNeonProduct?.displayPrice
                    Button(price ?? "Buy") {
                        Task { _ = await themeStore.purchaseMidnightNeon(theme: theme) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Link("Bug Submission", destination: URL(string: "mailto:coldcodebliss@gmail.com")!)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Support the Developer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if store.isLoading && store.products.isEmpty {
                        ProgressView().padding(.vertical, 4)
                    }

                    HStack(spacing: 10) {
                        ForEach(store.products, id: \.id) { product in
                            donateButton(for: product)
                        }
                    }

                    if let msg = store.lastMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                .overlay { neonOverlayCard(radius: 14) }  // ← Neon on inner card
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(".nexusStack helps freelancers, teams, and IT professionals manage jobs, deliverables, and GitHub repo's efficiently.")
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                .overlay { neonOverlayCard(radius: 14) }  // ← Neon on inner card
        }
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
        }
    }

    // MARK: - Donate button

    @ViewBuilder
    private func donateButton(for product: Product) -> some View {
        let glassOn = isBetaGlassEnabled

        Button {
            Task { await store.purchase(product) }
        } label: {
            Text(product.displayPrice)
                .font(.body.weight(.semibold))
                .frame(minWidth: 74)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Group {
                if #available(iOS 26.0, *), glassOn {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.85))
                }
            }
        )
        .foregroundStyle(glassOn ? Color.primary : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(glassOn ? 0.08 : 0)))
    }

    // MARK: - Neon overlays (ViewBuilder, no AnyView)

    @ViewBuilder
    private func neonOverlayPanel(radius: CGFloat) -> some View {
        if theme.currentID == .midnightNeon {
            let p = theme.palette(colorScheme)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            // Slightly softer than cards (bigger surface)
            let borderAlpha: Double    = isBetaGlassEnabled ? 0.22 : 0.28
            let tubeAlpha: Double      = isBetaGlassEnabled ? 0.48 : 0.58
            let innerGlowAlpha: Double = isBetaGlassEnabled ? 0.18 : 0.24
            let bloomAlpha: Double     = isBetaGlassEnabled ? 0.12 : 0.18

            ZStack {
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
        }
    }

    @ViewBuilder
    private func neonOverlayCard(radius: CGFloat) -> some View {
        if theme.currentID == .midnightNeon {
            let p = theme.palette(colorScheme)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            let borderAlpha: Double    = isBetaGlassEnabled ? 0.24 : 0.32
            let tubeAlpha: Double      = isBetaGlassEnabled ? 0.55 : 0.65
            let innerGlowAlpha: Double = isBetaGlassEnabled ? 0.22 : 0.28
            let bloomAlpha: Double     = isBetaGlassEnabled ? 0.14 : 0.20

            ZStack {
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
        }
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

// Tiny preview chip used in the Themes section
private struct ThemePreviewRow: View {
    var isNeon: Bool
    var body: some View {
        ZStack {
            if isNeon {
                LinearGradient(
                    colors: [
                        Color(hex: "#0B1020") ?? .black,
                        Color(hex: "#140F2A") ?? .black,
                        Color(hex: "#0F1326") ?? .black
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((Color(hex: "#2CF3FF") ?? .cyan).opacity(0.35), lineWidth: 1)
                        .shadow(color: (Color(hex: "#2CF3FF") ?? .cyan).opacity(0.20), radius: 8)
                )
            } else {
                Color(.secondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
