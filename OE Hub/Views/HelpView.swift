import SwiftUI

struct HelpView: View {
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private var useBetaGlass: Bool {
        if #available(iOS 26.0, *) { return isBetaGlassEnabled }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard(title: "Getting Started",
                                useBetaGlass: useBetaGlass) {
                        Label("Create your first Stack", systemImage: "folder.badge.plus")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap the **+** button in the top-right of Home to add a new stack. On iPad, select a stack in the sidebar.")
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Tabs Overview",
                                useBetaGlass: useBetaGlass) {
                        tipRow(icon: "calendar", title: "Due",
                               text: "Plan deliverables & reminders. Tap left side to rename; swipe to complete/color/delete.")
                        tipRow(icon: "checkmark.square", title: "Checklist",
                               text: "Light to-dos per stack.")

                        // Mind Map + indented mini-tips
                        VStack(alignment: .leading, spacing: 6) {
                            tipRow(icon: "point.topleft.down.curvedto.point.bottomright.up",
                                   title: "Mind Map",
                                   text: "Pinch to zoom, drag to pan; node drag sensitivity tuned for precision.")
                            VStack(alignment: .leading, spacing: 6) {
                                subTipRow(icon: "wand.and.stars",
                                          title: "Wand & Stars",
                                          text: "Auto-arranges nodes to tidy spacing and improve readability.")
                                subTipRow(icon: "target",
                                          title: "Target",
                                          text: "Re-centers the canvas on the root node to quickly find your map.")
                            }
                            .padding(.leading, 22) // slight visual indent
                        }

                        tipRow(icon: "note.text", title: "Notes",
                               text: "Rich text: bold, underline, strikethrough, bullets.")
                        tipRow(icon: "info.circle", title: "Info",
                               text: "Edit metadata; open GitHub & Confluence tools.")
                    }

                    SectionCard(title: "Toolbars & Integrations",
                                useBetaGlass: useBetaGlass) {
                        tipRow(icon: "link", title: "Confluence",
                               text: "Add up to 5 links per stack with Universal Links.")
                        tipRow(icon: "chevron.left.slash.chevron.right", title: "GitHub",
                               text: "Browse public repos, preview files, keep recents per stack.")
                    }

                    SectionCard(title: "Tips",
                                useBetaGlass: useBetaGlass) {
                        tipRow(icon: "bell", title: "Reminders",
                               text: "Quick offsets like 2w/1w/2d/day-of on each deliverable.")
                        tipRow(icon: "paintbrush", title: "Colors",
                               text: "Tint deliverables from swipe actions.")
                        tipRow(icon: "gear", title: "Appearance",
                               text: "Enable Liquid Glass and True Stack in Settings.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
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

// MARK: - Local SectionCard (Beta glass or standard)

private struct SectionCard<Content: View>: View {
    var title: String? = nil
    let useBetaGlass: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 2)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), useBetaGlass {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private var borderColor: Color {
        useBetaGlass ? .white.opacity(0.10) : .black.opacity(0.06)
    }
}
