import SwiftUI
import SwiftData

struct ChecklistsTabView: View {
    @Binding var newChecklistItem: String
    @Binding var addChecklistTrigger: Int          // nav-bar “+” trigger from parent
    var job: Job

    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        VStack(spacing: 16) {
            // Inline add form (shown via header + button OR toolbar trigger)
            if showAddChecklistForm {
                checklistForm
                    .padding(.top, formTopInset) // ← bump down to avoid clipping
            }

            checklistsList
        }
        .onAppear { showAddChecklistForm = false }
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
                    HStack {
                        Circle()
                            .fill(priorityColor(for: item.priorityLevel))
                            .frame(width: 12, height: 12)

                        Text(item.title)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

            // Completed (collapsible)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                item.isCompleted = false
                                item.completionDate = nil
                                try? modelContext.save()
                            } label: {
                                Label("Unmark", systemImage: "arrow.uturn.left")
                            }
                            .tint(.orange)
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
}
