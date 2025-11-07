import SwiftUI
import SwiftData
import UserNotifications

struct DueTabView: View {
    @Binding var newTaskDescription: String
    @Binding var newDueDate: Date
    @Binding var isCompletedSectionExpanded: Bool

    @Binding var addDeliverableTrigger: Int

    var job: Job

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAddDeliverableForm = false
    @State private var showCompletedDeliverables = false
    @State private var deliverableToDeletePermanently: Deliverable? = nil
    @State private var selectedDeliverable: Deliverable? = nil
    @State private var showColorPicker = false
    @State private var showReminderPicker = false

    // 🔹 NEW: rename state
    @State private var deliverableToRename: Deliverable? = nil
    @State private var renameText: String = ""
    private var isRenamingDeliverable: Binding<Bool> {
        Binding(
            get: { deliverableToRename != nil },
            set: { if !$0 { deliverableToRename = nil; renameText = "" } }
        )
    }

    // Classic flag removed
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private var activeDeliverables: [Deliverable] {
        job.deliverables
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var useWhiteGlow: Bool { isBetaGlassEnabled && colorScheme == .dark }
    private var whiteGlowColor: Color { Color.white.opacity(0.20) }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                if showAddDeliverableForm {
                    deliverableForm
                }

                deliverablesList

                if !completedDeliverables.isEmpty {
                    Button(action: { showCompletedDeliverables = true }) {
                        HStack {
                            Text("Completed Deliverables").font(.subheadline)
                            Image(systemName: "chevron.right").font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding()
                }
            }

            if activeDeliverables.isEmpty && !showAddDeliverableForm {
                DeliverablesEmptyState(glassOn: isBetaGlassEnabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // ⬇️ NEW: give the sheet a little breathing room at the very top
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 12)
            }
        .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
        .onAppear {
            showAddDeliverableForm = false
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        .onChange(of: addDeliverableTrigger) { _, _ in
            showAddDeliverableForm = true
        }

        .alert("Confirm Permanent Deletion", isPresented: Binding(
            get: { deliverableToDeletePermanently != nil },
            set: { if !$0 { deliverableToDeletePermanently = nil } }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                if let deliverable = deliverableToDeletePermanently {
                    modelContext.delete(deliverable)
                    try? modelContext.save()
                    removeAllNotifications(for: deliverable)
                }
            }
        } message: { Text("This action cannot be undone.") }

        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedItem: Binding(
                    get: { selectedDeliverable },
                    set: { selectedDeliverable = $0 as? Deliverable }
                ),
                isPresented: $showColorPicker
            )
            .presentationDetents([.medium])
        }

        .sheet(isPresented: Binding(
            get: { showReminderPicker && !isBetaGlassEnabled },
            set: { if !$0 { showReminderPicker = false } }
        )) {
            ReminderPickerView(selectedDeliverable: $selectedDeliverable, isPresented: $showReminderPicker)
                .presentationDetents([.medium])
        }
        .overlay {
            if showReminderPicker && isBetaGlassEnabled {
                ReminderPickerPanel(
                    selectedDeliverable: $selectedDeliverable,
                    isPresented: $showReminderPicker
                )
                .zIndex(3)
            }
        }

        .sheet(isPresented: Binding(
            get: { showCompletedDeliverables && !isBetaGlassEnabled },
            set: { if !$0 { showCompletedDeliverables = false } }
        )) {
            completedDeliverablesView
        }
        .overlay {
            if showCompletedDeliverables && isBetaGlassEnabled {
                CompletedDeliverablesPanel(
                    isPresented: $showCompletedDeliverables,
                    deliverableToDeletePermanently: $deliverableToDeletePermanently,
                    deliverables: completedDeliverables
                )
                .zIndex(4)
            }
        }

        // 🔹 Rename alert
        .alert("Rename Deliverable", isPresented: isRenamingDeliverable) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {
                deliverableToRename = nil
                renameText = ""
            }
            Button("Save") {
                if let d = deliverableToRename {
                    d.taskDescription = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? modelContext.save()
                }
                deliverableToRename = nil
                renameText = ""
            }
        } message: {
            Text("Update the deliverable name.")
        }
    }

    var completedDeliverables: [Deliverable] {
        job.deliverables.filter { $0.isCompleted }
    }

    // MARK: - Add Form

    @ViewBuilder
    private var deliverableForm: some View {
        VStack {
            Text("Add Deliverable").font(.title3.bold()).foregroundStyle(.primary)

            TextField("Task Description", text: $newTaskDescription)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            DatePicker("Due Date", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(.horizontal)

            HStack {
                Button(action: { showAddDeliverableForm = false }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.trailing)

                Button {
                    let newDeliverable = Deliverable(taskDescription: newTaskDescription, dueDate: newDueDate)
                    job.deliverables.append(newDeliverable)
                    newTaskDescription = ""
                    newDueDate = Date()
                    try? modelContext.save()
                    showAddDeliverableForm = false
                } label: {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .padding(.top, 8)
        .background(.ultraThinMaterial) // kept as-is (no Classic toggle dependency)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Active List

    @ViewBuilder
    private var deliverablesList: some View {
        List { activeDeliverablesSection }
            .scrollContentBackground(.hidden)
            .animation(.spring(duration: 0.3), value: job.deliverables)
    }

    @ViewBuilder
    private var activeDeliverablesSection: some View {
        Section(
            header:
                HStack(spacing: 8) {
                    Text("Active Deliverables")
                        .font(.headline)

                    Spacer()

                    // Glassy "+" button (matches app style)
                                Button {
                                    showAddDeliverableForm = true
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
                                            Circle()
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Circle())
                                .accessibilityLabel("Add Deliverable")
                            }
                            .padding(.vertical, 2)
        ) {
            ForEach(activeDeliverables) { deliverable in
                let tint = color(for: deliverable.colorCode)
                let radius: CGFloat = 12
                let isGlass = isBetaGlassEnabled
                let hasReminders = !deliverable.reminderOffsets.isEmpty

                HStack(alignment: .center) {
                    // Left column: tap to rename
                    VStack(alignment: .leading, spacing: 8) {
                        Text(deliverable.taskDescription)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Due")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(2)

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { deliverable.dueDate },
                                    set: { newValue in
                                        deliverable.dueDate = newValue
                                        try? modelContext.save()
                                        updateNotifications(for: deliverable)
                                    }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                            .accessibilityLabel("Due date")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { startRenaming(deliverable) }

                    Spacer(minLength: 8)

                    Button {
                        selectedDeliverable = deliverable
                        showReminderPicker = true
                    } label: {
                        Image(systemName: "bell").padding(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(hasReminders ? Color.black : Color.white)
                    .accessibilityLabel("Set reminders")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowBackground(tint: tint, radius: radius))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: useWhiteGlow ? whiteGlowColor
                                            : (isGlass ? .black.opacity(0.25) : .black.opacity(0.15)),
                        radius: useWhiteGlow ? 14 : (isGlass ? 14 : 5),
                        x: 0, y: useWhiteGlow ? 4 : (isGlass ? 8 : 0))

                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        deliverable.isCompleted = true
                        deliverable.completionDate = Date()
                        try? modelContext.save()
                        removeAllNotifications(for: deliverable)
                    } label: { Label("Mark Complete", systemImage: "checkmark") }
                    .tint(.green)

                    Button {
                        selectedDeliverable = deliverable
                        showColorPicker = true
                    } label: { Label("Change Color", systemImage: "paintbrush") }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if let idx = job.deliverables.firstIndex(of: deliverable) {
                            let removed = job.deliverables.remove(at: idx)
                            try? modelContext.save()
                            removeAllNotifications(for: removed)
                        }
                    } label: { Label("Delete", systemImage: "trash") }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                let toRemove = offsets.compactMap { activeDeliverables[safe: $0] }
                for d in toRemove {
                    if let idx = job.deliverables.firstIndex(of: d) {
                        let removed = job.deliverables.remove(at: idx)
                        removeAllNotifications(for: removed)
                    }
                }
                try? modelContext.save()
            }
        }
    }


    // MARK: - Completed Sheet (standard sheet version)

    @ViewBuilder
    private var completedDeliverablesView: some View {
        NavigationStack {
            List {
                ForEach(completedDeliverables) { deliverable in
                    let tint = color(for: deliverable.colorCode)
                    let radius: CGFloat = 12
                    let isGlass = isBetaGlassEnabled

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deliverable.taskDescription).font(.headline)
                        Text("Completed: \(formattedDate(deliverable.completionDate ?? Date()))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowBackground(tint: tint, radius: radius))
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: useWhiteGlow ? whiteGlowColor
                                                : (isGlass ? .black.opacity(0.25) : .black.opacity(0.15)),
                            radius: useWhiteGlow ? 16 : (isGlass ? 14 : 5),
                            x: 0, y: useWhiteGlow ? 6 : (isGlass ? 8 : 0))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deliverableToDeletePermanently = deliverable
                        } label: { Label("Total Deletion", systemImage: "trash.fill") }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Completed Deliverables")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCompletedDeliverables = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func startRenaming(_ deliverable: Deliverable) {
        deliverableToRename = deliverable
        renameText = deliverable.taskDescription
    }

    @ViewBuilder
    private func rowBackground(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear.glassEffect(.regular.tint(tint.opacity(0.50)), in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius).fill(
                    LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                )
                .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: radius).fill(tint)
        }
    }
}

// MARK: - Deliverables Empty State Bubble

private struct DeliverablesEmptyState: View {
    let glassOn: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("Tap the + to add a deliverable.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .padding(24)
        .background(bubbleBackground)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        .padding(24)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if #available(iOS 26.0, *), glassOn {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Completed Panel (Classic removed; Beta-only or tint fallback)

private struct CompletedDeliverablesPanel: View {
    @Binding var isPresented: Bool
    @Binding var deliverableToDeletePermanently: Deliverable?

    let deliverables: [Deliverable]

    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @Environment(\.colorScheme) private var colorScheme

    private var useWhiteGlow: Bool { isBetaGlassEnabled && colorScheme == .dark }
    private var whiteGlowColor: Color { Color.white.opacity(0.28) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 12) {
                HStack {
                    Text("Completed Deliverables").font(.headline)
                    Spacer()
                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .background(closeBackground)
                    .clipShape(Circle())
                }

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(deliverables) { d in
                            let tint = color(for: d.colorCode)
                            let radius: CGFloat = 12
                            let isGlass = isBetaGlassEnabled

                            VStack(alignment: .leading, spacing: 6) {
                                Text(d.taskDescription).font(.headline).foregroundStyle(.primary)
                                Text("Completed: \(formattedDate(d.completionDate ?? Date()))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowBackgroundPanel(tint: tint, radius: radius))
                            .clipShape(RoundedRectangle(cornerRadius: radius))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius)
                                    .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                            )
                            .shadow(color: useWhiteGlow ? whiteGlowColor
                                                        : (isGlass ? .black.opacity(0.25) : .black.opacity(0.15)),
                                    radius: useWhiteGlow ? 16 : (isGlass ? 14 : 5),
                                    x: 0, y: useWhiteGlow ? 6 : (isGlass ? 8 : 0))
                            .contextMenu {
                                Button(role: .destructive) { deliverableToDeletePermanently = d } label: {
                                    Label("Delete Permanently", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 560)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
                RoundedRectangle(cornerRadius: 20).fill(
                    LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                ).blendMode(.plusLighter)
            }
        } else {
            // keep simple material as non-glass fallback for panel
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    @ViewBuilder private var closeBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .circle)
        } else { Circle().fill(.ultraThinMaterial) }
    }

    @ViewBuilder private func rowBackgroundPanel(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear.glassEffect(.regular.tint(tint.opacity(0.5)), in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius).fill(
                    LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                ).blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: radius).fill(tint)
        }
    }
}

// MARK: - Notification Utilities

fileprivate func updateNotifications(for deliverable: Deliverable) {
    removeAllNotifications(for: deliverable)
    guard !deliverable.reminderOffsets.isEmpty else { return }

    let content = UNMutableNotificationContent()
    content.title = "Deliverable Reminder"
    content.body = "\(deliverable.taskDescription) is due on \(formattedDate(deliverable.dueDate))"
    content.sound = UNNotificationSound.default

    let idPrefix = String(describing: deliverable.persistentModelID)
    for offset in deliverable.reminderOffsets {
        if let triggerDate = calculateTriggerDate(for: offset, dueDate: deliverable.dueDate),
           triggerDate > Date() {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(idPrefix)-\(offset)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("Notification error: \(error)") }
            }
        }
    }
}

fileprivate func removeAllNotifications(for deliverable: Deliverable) {
    let idPrefix = String(describing: deliverable.persistentModelID)
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        let ids = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix + "-") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

fileprivate func calculateTriggerDate(for offset: String, dueDate: Date) -> Date? {
    let calendar = Calendar.current
    switch offset.lowercased() {
    case "2weeks": return calendar.date(byAdding: .day, value: -14, to: dueDate)
    case "1week":  return calendar.date(byAdding: .day, value: -7,  to: dueDate)
    case "2days":  return calendar.date(byAdding: .day, value: -2,  to: dueDate)
    case "dayof":  return dueDate
    default:       return nil
    }
}

fileprivate func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy"
    return formatter.string(from: date)
}

fileprivate extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
