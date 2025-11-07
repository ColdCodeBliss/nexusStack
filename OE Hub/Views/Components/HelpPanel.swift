import SwiftUI

struct HelpPanel: View {
    @Binding var isPresented: Bool

    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false   // Real glass (iOS 26+)

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
                                    .padding(.leading, 22) // slight visual indent to show these belong to Mind Map
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
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Reusable subviews

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
        else {
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func Card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
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

    // NEW: small, indented sub-tip row used under “Mind Map”
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
}
