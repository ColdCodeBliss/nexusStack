//
//  WidgetSharedKey.swift
//  OE Hub
//
//  Created by Ryan Bliss on 11/18/25.
//


import WidgetKit
import SwiftUI

// MARK: - Shared constants

/// Replace this with your real App Group identifier.
private let appGroupID = "group.com.coldcodebliss.nexusstack"

/// Keys used in the shared UserDefaults for widget data.
private enum WidgetSharedKey {
    static let jobCount = "widgetJobCount"
    static let selectedThemeID = "selectedThemeID" // mirrors ThemeManager's AppStorage key
}

// MARK: - Timeline Entry

struct NeonDeckGlanceEntry: TimelineEntry {
    let date: Date
    let jobCount: Int
    let isMidnightNeonActive: Bool
}

// MARK: - Timeline Provider

struct NeonDeckGlanceProvider: TimelineProvider {

    func placeholder(in context: Context) -> NeonDeckGlanceEntry {
        NeonDeckGlanceEntry(
            date: Date(),
            jobCount: 5,
            isMidnightNeonActive: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NeonDeckGlanceEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeonDeckGlanceEntry>) -> Void) {
        let entry = loadCurrentEntry()

        // Simple: refresh every 30 minutes.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    // MARK: - Helpers

    private func loadCurrentEntry() -> NeonDeckGlanceEntry {
        let defaults = UserDefaults(suiteName: appGroupID)

        let jobCount = defaults?.integer(forKey: WidgetSharedKey.jobCount) ?? 0
        let themeID = defaults?.string(forKey: WidgetSharedKey.selectedThemeID) ?? "system"
        let isNeon = (themeID == "midnightNeon")

        return NeonDeckGlanceEntry(
            date: Date(),
            jobCount: jobCount,
            isMidnightNeonActive: isNeon
        )
    }
}

// MARK: - Widget View

struct NeonDeckGlanceWidgetEntryView: View {
    var entry: NeonDeckGlanceEntry

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 10) {
                deckVisualization

                VStack(spacing: 2) {
                    Text("\(entry.jobCount) job\(entry.jobCount == 1 ? "" : "s") in your stack")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Tap to open .nexusStack")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        // Deep link; you can handle `nexusstack://open` in the main app.
        .widgetURL(URL(string: "nexusstack://open"))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if entry.isMidnightNeonActive {
            // If you also add MidnightNeonDeckBackground.swift to the widget target,
            // you can use it directly here:
            //
            // MidnightNeonDeckBackground()
            //
            // For safety, here’s a simplified inline version:

            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.02, blue: 0.10),
                    Color(red: 0.02, green: 0.03, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                // Simple neon grid
                GeometryReader { proxy in
                    let size = proxy.size
                    Canvas { context, _ in
                        let spacing: CGFloat = 16
                        var path = Path()

                        // Vertical lines
                        var x: CGFloat = 0
                        while x <= size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                            x += spacing
                        }

                        // Horizontal lines
                        var y: CGFloat = 0
                        while y <= size.height {
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            y += spacing
                        }

                        var gridStyle = GraphicsContext.StrokeStyle()
                        gridStyle.lineWidth = 0.7

                        context.stroke(
                            path,
                            with: .color(Color.cyan.opacity(0.38)),
                            style: gridStyle
                        )
                    }
                    .blendMode(.plusLighter)
                }
            )
        } else {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Deck Visualization

    private var deckVisualization: some View {
        ZStack {
            let cardCount = 4
            ForEach(0..<cardCount, id: \.self) { index in
                let offset = CGFloat(cardCount - index) * 4.0
                let scale = 1.0 - (CGFloat(index) * 0.05)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill(for: index))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(cardStroke(for: index), lineWidth: 1.2)
                    )
                    .shadow(color: shadowColor(for: index), radius: 12, x: 0, y: 0)
                    .scaleEffect(scale)
                    .offset(y: offset)
            }

            // Tiny top-glow accent line
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(entry.isMidnightNeonActive ? 0.65 : 0.20), lineWidth: 1)
                .frame(width: 72, height: 16)
                .offset(y: -22)
                .blendMode(.plusLighter)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
    }

    private func cardFill(for index: Int) -> LinearGradient {
        if entry.isMidnightNeonActive {
            let base = Color(red: 0.05, green: 0.04, blue: 0.15)
            let top = Color(red: 0.12 + Double(index) * 0.02,
                            green: 0.05,
                            blue: 0.25 + Double(index) * 0.03)

            return LinearGradient(
                colors: [top, base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            let base = Color(.systemBackground)
            let top = Color(.secondarySystemBackground)
            return LinearGradient(
                colors: [top, base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func cardStroke(for index: Int) -> Color {
        if entry.isMidnightNeonActive {
            let base = Color.cyan
            return base.opacity(0.55 + Double(index) * 0.1)
        } else {
            return Color.black.opacity(0.08 + Double(index) * 0.04)
        }
    }

    private func shadowColor(for index: Int) -> Color {
        if entry.isMidnightNeonActive {
            return Color.cyan.opacity(0.25 + Double(index) * 0.05)
        } else {
            return Color.black.opacity(0.08)
        }
    }
}

// MARK: - Widget

struct NeonDeckGlanceWidget: Widget {
    let kind: String = "NeonDeckGlanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NeonDeckGlanceProvider()) { entry in
            NeonDeckGlanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(".nexusStack – Deck Glance")
        .description("A miniature deck-like glance with your current job count.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct NexusStackWidgets: WidgetBundle {
    var body: some Widget {
        NeonDeckGlanceWidget()
    }
}
