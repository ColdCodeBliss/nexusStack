import SwiftUI
import StoreKit

struct SettingsPanel: View {
    @Binding var isPresented: Bool

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real glass (iOS 26+)
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.60
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false

    @StateObject private var store = DonationStore()

    var body: some View {
        ZStack {
            // Dimmed backdrop; tap outside to dismiss
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Floating panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Appearance
                        Group {
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
                            .animation(.default, value: isBetaGlassEnabled)
                        }

                        // Support
                        Group {
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
                            }
                        }

                        // About
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
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 520)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
            .task { await store.load() }
        }
    }

    // Panel (outer) background: true Liquid Glass when available, else standard background
    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    // Inner card background
    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
        }
    }

    // Donate button styled to match the panel
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
        .padding(.vertical, 8).padding(.horizontal, 12)
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
}
