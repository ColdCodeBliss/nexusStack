import SwiftUI
import SwiftData

struct ChecklistsTabView: View {
    @Binding var newChecklistItem: String
    @Binding var addChecklistTrigger: Int          // nav-bar “+” trigger from parent
    var job: Job

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var theme: ThemeManager
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    @State private var isCompletedSectionExpanded: Bool = false
    @State private var showAddChecklistForm: Bool = false
    @State private var selectedChecklistItem: ChecklistItem? = nil
    @State private var showColorPicker = false
    @State private var showClearConfirmation = false

    // Match the DueTabView top bump so the inline sheet doesn’t clip
    private let formTopInset: CGFloat = 12

    // Precompute filtered arrays to keep indices stable & avoid repeated work
    private var activeItems: [ChecklistItem]   { job.checklistItems.filter { !$0.isCompleted } }
    private var completedItems: [ChecklistItem]{ job.checklistItems.filter {  $0.isCompleted } }

    // Shared flicker for all rows in this screen (Midnight Neon only)
    @State private var neonFlicker: Double = 1.0
    @State private var flickerArmed: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Inline add form (shown via header + button OR toolbar trigger)
            if showAddChecklistForm {
                checklistForm
                    .padding(.top, formTopInset) // ← bump down to avoid clipping
            }

            checklistsList
        }
        .onAppear {
            showAddChecklistForm = false
            armFlickerIfNeeded()
        }
        .onDisappear { flickerArmed = false }
        .onChange(of: theme.currentID) { _, _ in armFlickerIfNeeded() }

        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedItem: Binding(
                    get: { selectedChecklistItem },
                    set: { selectedChecklistItem = $0 as? ChecklistItem }
                ),
                isPresented: $showColorPicker
            )
            .presentationDetents([.medium])
        }
        .alert("Clear Completed Checklists", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { clearCompletedChecklists() }
        } message: {
            Text("Are you sure you want to permanently delete all completed checklists? This action cannot be undone.")
        }
        // Open the inline add form whenever the parent increments the trigger
        .onChange(of: addChecklistTrigger) { _, _ in
            newChecklistItem = ""
            withAnimation { showAddChecklistForm = true }
        }
    }

    // MARK: - Add Form

    @ViewBuilder
    private var checklistForm: some View {
        VStack {
            Text("Add Checklist Item")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            TextField("Item Description", text: $newChecklistItem)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal)

            HStack {
                Button {
                    withAnimation { showAddChecklistForm = false }
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.trailing)

                Button(action: addChecklistItem) {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newChecklistItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Lists

    @ViewBuilder
    private var checklistsList: some View {
        List {
            // Active with glassy "+" button in the header (matches Deliverables/Notes)
            Section(
                header:
                    HStack(spacing: 8) {
                        Text("Active Checklists")
                            .font(.headline)

                        Spacer()

                        Button {
                            newChecklistItem = ""
                            withAnimation { showAddChecklistForm = true }
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .background(
                                    Group {
                                        if #available(iOS 26.0, *), isBetaGlassEnabled {
                                            Color.clear.glassEffect(.regular, in: .circle)
                                        } else {
                                            Circle().fill(.ultraThinMaterial)
                                        }
                                    }
                                )
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .accessibilityLabel("Add Checklist Item")
                    }
                    .padding(.vertical, 2)
            ) {
                ForEach(activeItems) { item in
                    let radius: CGFloat = 12
                    HStack {
                        Circle()
                            .fill(priorityColor(for: item.priorityLevel))
                            .frame(width: 12, height: 12)

                        Text(item.title)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: radius))

                    // Hairline stroke (original)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )

                    // Midnight Neon tube + inner glows (no shadows, fully contained)
                    .overlay(neonOverlayRow(radius: radius, completed: false))

                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            item.isCompleted = true
                            item.completionDate = Date()
                            try? modelContext.save()
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark")
                        }
                        .tint(.green)

                        Button {
                            selectedChecklistItem = item
                            showColorPicker = true
                        } label: {
                            Label("Change Color", systemImage: "paintbrush")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = job.checklistItems.firstIndex(of: item) {
                                job.checklistItems.remove(at: index)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            // Completed (collapsible) — now with a softer neon look
            Section(
                header:
                    HStack {
                        Text("Completed Checklists (\(completedItems.count))")
                            .font(.headline)
                        Spacer()
                        Image(systemName: isCompletedSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundStyle(.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { isCompletedSectionExpanded.toggle() } }
            ) {
                if isCompletedSectionExpanded {
                    ForEach(completedItems) { item in
                        let radius: CGFloat = 12
                        HStack {
                            Circle()
                                .fill(priorityColor(for: item.priorityLevel))
                                .frame(width: 12, height: 12)

                            Text(item.title)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.completionDate ?? Date(),
                                 format: .dateTime.month(.twoDigits).day(.twoDigits).year(.defaultDigits))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )

                        // NEW: Softer neon treatment for completed items
                        .overlay(neonOverlayRow(radius: radius, completed: true))
                    }

                    if !completedItems.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Completed", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .animation(.default, value: job.checklistItems.count)
    }

    // MARK: - Actions

    private func addChecklistItem() {
        withAnimation {
            let newItem = ChecklistItem(title: newChecklistItem)
            job.checklistItems.append(newItem)
            newChecklistItem = ""
            try? modelContext.save()
            showAddChecklistForm = false
        }
    }

    private func clearCompletedChecklists() {
        for item in completedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    // MARK: - Neon overlay (tube + glows, masked to row rect)
    // `completed: true` slightly reduces intensity to avoid competing with active items.
    private func neonOverlayRow(radius: CGFloat, completed: Bool) -> some View {
        // Early exit: if theme isn't Neon, return an empty view with a concrete type.
        guard theme.currentID == .midnightNeon else { return AnyView(EmptyView()) }

        // Compute locals OUTSIDE of the builder to avoid inference issues.
        let p = theme.palette(colorScheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // Base alphas
        var borderAlpha    = isBetaGlassEnabled ? 0.24 : 0.32
        var tubeAlpha      = isBetaGlassEnabled ? 0.55 : 0.65
        var innerGlowAlpha = isBetaGlassEnabled ? 0.22 : 0.28
        var bloomAlpha     = isBetaGlassEnabled ? 0.14 : 0.20

        // Completed rows get a softer treatment
        if completed {
            borderAlpha    *= 0.85
            tubeAlpha      *= 0.75
            innerGlowAlpha *= 0.75
            bloomAlpha     *= 0.70
        }

        // Build the overlay as a single concrete type and erase to AnyView.
        let overlay = ZStack {
            // 1) crisp inset border
            shape
                .strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)

            // 2) tube core (thin bright line)
            shape
                .stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 2))

            // 3) tight inner glow
            shape
                .stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 8)
                .blur(radius: 9)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 10))

            // 4) inner bloom
            shape
                .stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 14)
                .blur(radius: 16)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 16))
        }

        return AnyView(overlay)
    }


    // MARK: - Flicker

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
