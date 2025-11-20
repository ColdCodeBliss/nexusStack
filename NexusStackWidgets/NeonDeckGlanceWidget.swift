//
//  NeonDeckGlanceWidget.swift
//  OE Hub
//
//  Created by Ryan Bliss on 11/18/25.
//

import WidgetKit
import SwiftUI

// MARK: - Shared constants

/// App Group identifier shared with the main app.
private let appGroupID = "group.com.coldcodebliss.nexusstack"

/// Keys used in the shared UserDefaults for widget data.
private enum WidgetSharedKey {
    // NOTE: jobCount removed – widget now only cares about weekly deliverables + theme.
    static let selectedThemeID     = "selectedThemeID"          // mirrors ThemeManager's AppStorage key
    static let weeklyDeliverables  = "widgetWeeklyDeliverables" // total active deliverables
}

private var neonMagenta: Color {
    Color(red: 1.0, green: 0.25, blue: 0.75) // tweak if you want a different magenta
}

// MARK: - Timeline Entry

struct NeonDeckGlanceEntry: TimelineEntry {
    let date: Date
    let weeklyDeliverables: Int
    let isMidnightNeonActive: Bool
}

// MARK: - Timeline Provider

struct NeonDeckGlanceProvider: TimelineProvider {

    func placeholder(in context: Context) -> NeonDeckGlanceEntry {
        NeonDeckGlanceEntry(
            date: Date(),
            weeklyDeliverables: 12,
            isMidnightNeonActive: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NeonDeckGlanceEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeonDeckGlanceEntry>) -> Void) {
        let entry = loadCurrentEntry()

        // Refresh every 30 minutes.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }

    // MARK: - Helpers

    private func loadCurrentEntry() -> NeonDeckGlanceEntry {
        let defaults = UserDefaults(suiteName: appGroupID)

        let weekly = defaults?.integer(forKey: WidgetSharedKey.weeklyDeliverables) ?? 0
        let themeID = defaults?.string(forKey: WidgetSharedKey.selectedThemeID) ?? "system"
        let isNeon = (themeID == "midnightNeon")

        return NeonDeckGlanceEntry(
            date: Date(),
            weeklyDeliverables: weekly,
            isMidnightNeonActive: isNeon
        )
    }
}

// MARK: - Widget View

struct NeonDeckGlanceWidgetEntryView: View {
    var entry: NeonDeckGlanceEntry

    @Environment(\.widgetFamily) private var family

    // Always read the latest theme from the shared App Group; fall back to entry.
    private var isNeon: Bool {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            let id = defaults.string(forKey: WidgetSharedKey.selectedThemeID)
                ?? (entry.isMidnightNeonActive ? "midnightNeon" : "system")
            return id == "midnightNeon"
        }
        return entry.isMidnightNeonActive
    }

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                leftCard
                rightCard
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            backgroundLayer
        }
        .widgetURL(URL(string: "nexusstack://open"))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        if isNeon {
            // NEON: full-bleed gradient + grid
            GeometryReader { proxy in
                let size = proxy.size

                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.02, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
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

                        context.stroke(
                            path,
                            with: .color(Color.cyan.opacity(0.38)),
                            lineWidth: 0.7
                        )
                    }
                    .blendMode(.plusLighter)
                )
            }
        } else {
            // NON-NEON: solid black background
            Color.black
        }
    }

    // MARK: - Cards

    private var leftCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(cardFill(for: 0))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(cardStroke(for: 0), lineWidth: 1.4)
            )
            .shadow(
                color: shadowColor(for: 0),
                radius: isNeon ? 12 : 6,
                x: 0, y: 4
            )
            .overlay(
                VStack(spacing: 4) {
                    Text(family == .systemSmall ? "DUE" : "WEEKLY DELIVERABLES")
                        .font(.custom("BerkeleyMono-Bold", size: 10))
                        .tracking(0.8)
                        .opacity(0.9)
                        .foregroundStyle(isNeon ? neonMagenta : Color.black)

                    Text("\(entry.weeklyDeliverables)")
                        .font(.custom("BerkeleyMono-Bold", size: 20))
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isNeon ? Color.cyan : Color.black)
                }
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            )
    }


    private var rightCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(cardFill(for: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(cardStroke(for: 1), lineWidth: 1.4)
            )
            .shadow(
                color: shadowColor(for: 1),
                radius: isNeon ? 12 : 6,
                x: 0, y: 4
            )
            .overlay(
                Image(isNeon ? "nexusStack_logo_neon_b" : "nexusStack_logo_icon")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .padding(10)
            )
    }

    // MARK: - Card styling

    private func cardFill(for index: Int) -> LinearGradient {
        if isNeon {
            // NEON: deep purple cards
            let baseTop = Color(
                red: 0.21 + Double(index) * 0.02,
                green: 0.05,
                blue: 0.35 + Double(index) * 0.03
            )
            let baseBottom = Color(red: 0.05, green: 0.04, blue: 0.15)

            return LinearGradient(
                colors: [baseTop, baseBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // NON-NEON:
            // left card (index 0) = yellow, right card (index 1) = black
            if index == 0 {
                let yellow = Color(red: 0.99, green: 0.86, blue: 0.25)
                return LinearGradient(
                    colors: [yellow.opacity(0.98), yellow.opacity(0.90)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                let blackTop = Color(red: 0.06, green: 0.06, blue: 0.06)
                let blackBottom = Color.black
                return LinearGradient(
                    colors: [blackTop, blackBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func cardStroke(for index: Int) -> Color {
        if isNeon {
            let base = Color.cyan
            return base.opacity(0.55 + Double(index) * 0.1)
        } else {
            // NON-NEON: left card black border, right card yellow border
            if index == 0 {
                return Color.black
            } else {
                return Color(red: 0.99, green: 0.86, blue: 0.25)
            }
        }
    }

    private func shadowColor(for index: Int) -> Color {
        if isNeon {
            return Color.cyan.opacity(0.20 + Double(index) * 0.05)
        } else {
            return Color.black.opacity(0.6)
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
        .description("A miniature glance showing your active deliverables and theme.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
