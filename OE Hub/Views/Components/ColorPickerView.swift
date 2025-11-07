//
//  ColorPickerView.swift
//  nexusStack / OE Hub
//

import SwiftUI
import SwiftData

struct ColorPickerView: View {
    @Binding var selectedItem: Any?
    @Binding var isPresented: Bool

    // Use Job’s canonical palette order so indices match everywhere.
    private let palette = Job.ColorCode.ordered.map { $0.rawValue } // ["gray","red","blue",...]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Color")
                    .font(.title2).bold()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                    ForEach(palette, id: \.self) { colorName in
                        let tint = color(for: colorName)
                        let isSelected = isCurrentlySelected(colorName)

                        Button {
                            apply(colorName)
                            isPresented = false
                        } label: {
                            chipView(tint: tint, isSelected: isSelected, colorName: colorName)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                    }
                }
                .padding()
            }
            .navigationTitle("Color Picker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Chip View (glassy when Liquid Glass is ON)

    @ViewBuilder
    private func chipView(tint: Color, isSelected: Bool, colorName: String) -> some View {
        let chip = Group {
            if isLiquidGlassEnabled {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(tint.opacity(0.65)))
                    .overlay(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                    )
            } else {
                Circle().fill(tint)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(
            Circle().stroke(
                isSelected ? Color.primary : Color.black.opacity(0.2),
                lineWidth: isSelected ? 2 : 1
            )
        )
        .accessibilityLabel(Text(colorName.capitalized))

        chip
    }

    // MARK: - Apply selection

    private func apply(_ colorName: String) {
        // Map the tapped name to Job’s canonical index
        let idx = Job.ColorCode.index(for: colorName)

        if let job = selectedItem as? Job {
            // ✅ Unified write: updates both colorIndex and colorCode
            job.setColor(index: idx)
        } else if let checklistItem = selectedItem as? ChecklistItem {
            // Keep existing semantics (priority stored as capitalized name)
            checklistItem.priority = colorName.capitalized
        } else if let deliverable = selectedItem as? Deliverable {
            // Keep existing semantics for deliverables
            deliverable.colorCode = colorName
        }
        try? modelContext.save()
    }

    private func isCurrentlySelected(_ colorName: String) -> Bool {
        let idx = Job.ColorCode.index(for: colorName)

        if let job = selectedItem as? Job {
            // ✅ Compare against unified index
            return job.effectiveColorIndex == idx
        } else if let checklistItem = selectedItem as? ChecklistItem {
            return checklistItem.priority.lowercased() == colorName
        } else if let deliverable = selectedItem as? Deliverable {
            return (deliverable.colorCode?.lowercased() ?? "") == colorName
        }
        return false
    }
}
