//
//  TrueStackExpandedView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/24/25.
//

import SwiftUI

@available(iOS 26.0, *)
struct TrueStackExpandedView: View {
    // MARK: Inputs
    let job: Job

    // Callbacks (wired by TSDV)
    let close: () -> Void
    let openDue: () -> Void
    let openChecklist: () -> Void
    let openMindMap: () -> Void
    let openNotes: () -> Void
    let openInfo: () -> Void
    let openGitHub: () -> Void
    let openConfluence: () -> Void

    // MARK: State (for drag-to-dismiss)
    @State private var dragOffsetY: CGFloat = 0
    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            // Bottom sheet sizing: wide enough, tall enough, but leaves a little space at the top
            let maxW  = min(geo.size.width  * 0.96, 700)
            let maxH  = geo.size.height * 0.90
            let tint  = color(for: job.colorCode)

            VStack(spacing: 0) {
                // Header (chevron down + grabber)
                HStack(spacing: 10) {
                    Button(action: close) {
                        Image(systemName: "chevron.down")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .glassButton()

                    Spacer()

                    Capsule()
                        .frame(width: 44, height: 4)
                        .opacity(0.25)
                        .padding(.trailing, 6)
                }
                .padding(.top, 8)
                .padding(.horizontal, 10)

                // Title
                Text(job.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                // Content (scrolls when needed — avoids landscape overflow)
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 10) {
                        ActionRow(system: "calendar",
                                  title: "Due",
                                  blurb: "Deliverables & reminders",
                                  action: openDue)

                        ActionRow(system: "checkmark.square",
                                  title: "Checklist",
                                  blurb: "Quick to-do items per stack",
                                  action: openChecklist)

                        ActionRow(system: "point.topleft.down.curvedto.point.bottomright.up",
                                  title: "Mind Map",
                                  blurb: "Zoomable canvas of ideas",
                                  action: openMindMap)

                        ActionRow(system: "note.text",
                                  title: "Notes",
                                  blurb: "Rich text with basic formatting",
                                  action: openNotes)

                        ActionRow(system: "info.circle",
                                  title: "Info",
                                  blurb: "Metadata, pay, role & more",
                                  action: openInfo)

                        ActionRow(system: "chevron.left.slash.chevron.right",
                                  title: "GitHub",
                                  blurb: "Browse repo files & recents",
                                  action: openGitHub)

                        ActionRow(system: "link",
                                  title: "Confluence",
                                  blurb: "Save up to 5 links per stack",
                                  action: openConfluence)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
            }
            // Sheet chrome & layout
            .frame(width: maxW)                              // cap width
            .frame(maxHeight: maxH, alignment: .top)         // cap height (lets ScrollView handle overflow)
            .background(
                ZStack {
                    // Tinted glass (matches job color)
                    Color.clear.glassEffect(.regular.tint(tint.opacity(0.55)),
                                             in: .rect(cornerRadius: 24))
                    // Subtle plus-lighter glow layer
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .blendMode(.plusLighter)
                    // Hairline stroke
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
            .padding(.horizontal, 12)
            .padding(.bottom, max(12, geo.safeAreaInsets.bottom + 8)) // keep off the very bottom edge

            // Live drag offset while swiping down
            .offset(y: max(0, dragOffsetY + dragTranslation.height))

            // Lock to bottom of the screen, slide in/out from bottom
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))

            // Drag-to-dismiss (with a sensible threshold)
            .gesture(dragGesture(geoHeight: geo.size.height))

            // Smoothen the drag animation
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: dragTranslation)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: dragOffsetY)
        }
    }

    private func dragGesture(geoHeight: CGFloat) -> some Gesture {
        let threshold: CGFloat = min(220, geoHeight * 0.25)
        return DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                state = CGSize(width: 0, height: max(0, value.translation.height))
            }
            .onEnded { value in
                let shouldClose = value.translation.height > threshold || value.velocity.height > 900
                if shouldClose { close() } else { dragOffsetY = 0 }
            }
    }
}

// MARK: - Action Row

@available(iOS 26.0, *)
private struct ActionRow: View {
    let system: String
    let title: String
    let blurb: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: system)
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.45)
            }
            .padding(12)
        }
        .glassButton()
        .accessibilityElement(children: .combine)
    }
}
