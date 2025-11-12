import SwiftUI
import SwiftData

struct HomeView: View {
    // Queries (initialized in init to ease the type checker)
    @Query private var jobs: [Job]
    @Query private var deletedJobs: [Job]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize

    // UI State
    @State private var isRenaming = false
    @State private var jobToRename: Job?
    @State private var newJobTitle = ""

    @State private var showJobHistory = false
    @State private var jobToDeletePermanently: Job?

    // iPhone-style push navigation
    @State private var navJob: Job? = nil

    // iPad-style sidebar selection (Hashable)
    @State private var splitSelectionID: PersistentIdentifier? = nil

    // Color picker & settings
    @State private var selectedJob: Job?
    @State private var showColorPicker = false
    @State private var showSettings = false
    @State private var showHelp = false

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false

    // Existing hero metrics (used on iPhone flow only)
    private let heroLogoHeight: CGFloat = 120   // logo size (applies to both standard & neon)
    private let heroTopOffset: CGFloat = 0      // distance from button row
    // NEW: cap the logo’s width so neon art can’t appear wider than standard
    private let heroLogoMaxWidth: CGFloat = 420

    // MARK: - Init: move #Predicate here (reduces compiler load)
    init() {
        _jobs = Query(
            filter: #Predicate<Job> { !$0.isDeleted },
            sort: [SortDescriptor(\.creationDate, order: .forward)]
        )
        _deletedJobs = Query(
            filter: #Predicate<Job> { $0.isDeleted },
            sort: [SortDescriptor(\.deletionDate, order: .reverse)]
        )
    }

    var body: some View {
        // ✅ When Beta Glass *and* True Stack are ON (iOS 26+), show the Card Deck host.
        if #available(iOS 26.0, *), isBetaGlassEnabled && isTrueStackEnabled {
            TrueStackDeckHost(jobs: jobs)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        } else {
            // Branch by size class: regular = iPad (split), compact = iPhone (existing flow)
            if hSize == .regular {
                iPadSplitView
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            } else {
                iPhoneStackView
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
    }

    // MARK: - iPhone (existing NavigationStack flow, now with empty-state overlay)

    private var iPhoneStackView: some View {
        GeometryReader { geo in
            // Detect “Dynamic Island” style top inset (≈54pt+ on 14 Pro/15 family)
            let topInset = geo.safeAreaInsets.top
            let isDynamicIsland = topInset >= 54
            let logoYOffset: CGFloat = isDynamicIsland ? -88 : -70
            let listGapBelowLogo: CGFloat = isDynamicIsland ? -38 : -28

            NavigationStack {
                ZStack {
                    VStack {
                        jobList
                        jobHistoryButton
                    }
                    // Push content down to sit under the overlayed logo
                    .padding(.top, max(0, heroLogoHeight + heroTopOffset + listGapBelowLogo + logoYOffset))

                    // -------- iPhone Empty State Overlay --------
                    if jobs.isEmpty {
                        iPhoneEmptyState(glassOn: isBetaGlassEnabled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .navigationDestination(isPresented: Binding(
                    get: { navJob != nil },
                    set: { if !$0 { navJob = nil } }
                )) {
                    if let job = navJob {
                        JobDetailView(job: job)
                    }
                }

                // Overlay hero logo (iPhone only)
                .overlay(alignment: .top) {
                    // Wrap in a strict frame so both standard & neon assets render at identical size
                    HeroLogoRow(height: heroLogoHeight)
                        .frame(
                            maxWidth: heroLogoMaxWidth,
                            minHeight: heroLogoHeight,
                            maxHeight: heroLogoHeight,
                            alignment: .center
                        )
                        .padding(.top, heroTopOffset)
                        .padding(.horizontal, 16)
                        .offset(y: logoYOffset)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }

                .background(Gradient(colors: [.blue, .purple]).opacity(0.1))

                // Sheets & alerts (unchanged)
                .sheet(isPresented: $showJobHistory) {
                    JobHistorySheetView(
                        deletedJobs: deletedJobs,
                        jobToDeletePermanently: $jobToDeletePermanently,
                        onDone: { showJobHistory = false }
                    )
                }
                .sheet(isPresented: Binding(
                    get: { showSettings && !isBetaGlassEnabled },
                    set: { if !$0 { showSettings = false } }
                )) {
                    SettingsView()
                }
                .sheet(isPresented: $showColorPicker) {
                    ColorPickerView(
                        selectedItem: selectedItemBinding,
                        isPresented: $showColorPicker
                    )
                    .presentationDetents([.medium])
                }
                .alert("Rename Job", isPresented: $isRenaming) { renameAlertButtons }
                .alert("Confirm Permanent Deletion", isPresented: deletionAlertFlag) {
                    deletionAlertButtons
                } message: { Text("This action cannot be undone.") }

                // Settings as floating panel when Beta Glass ON
                .overlay {
                    if showSettings && isBetaGlassEnabled {
                        SettingsPanel(isPresented: $showSettings)
                            .zIndex(2)
                    }
                }
                // Help as sheet when Beta OFF
                .sheet(isPresented: Binding(
                    get: { showHelp && !isBetaGlassEnabled },
                    set: { if !$0 { showHelp = false } }
                )) {
                    HelpView()
                }

                // Help as floating glass panel when Beta ON
                .overlay {
                    if showHelp && isBetaGlassEnabled {
                        HelpPanel(isPresented: $showHelp)
                            .zIndex(3)
                    }
                }
            }
        }
    }

    // MARK: - iPad (NavigationSplitView with sidebar + detail)

    private var iPadSplitView: some View {
        NavigationSplitView {
            List(selection: $splitSelectionID) {
                ForEach(jobs, id: \.persistentModelID) { (job: Job) in
                    JobRowView(job: job)
                        .contentShape(Rectangle())
                        .tag(job.persistentModelID)
                        .contextMenu {
                            Button("Rename") { startRenaming(job) }
                            Button("Change Color") {
                                selectedJob = job
                                showColorPicker = true
                            }
                            Button("Delete", role: .destructive) {
                                softDelete(job)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { startRenaming(job) } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                            Button {
                                selectedJob = job
                                showColorPicker = true
                            } label: {
                                Label("Change Color", systemImage: "paintbrush")
                            }
                            .tint(.green)
                        }
                        .swipeActions {
                            Button(role: .destructive) { softDelete(job) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete(perform: deleteJob)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .toolbar { toolbarContent }
            .navigationTitle(".nexusStack")

            // Footer button (kept near sidebar bottom)
            .safeAreaInset(edge: .bottom) {
                if !deletedJobs.isEmpty {
                    Button { showJobHistory = true } label: {
                        HStack {
                            Text("Stack History").font(.subheadline)
                            Image(systemName: "chevron.right").font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                }
            }

        } detail: {
            if let id = splitSelectionID,
               let job = jobs.first(where: { $0.persistentModelID == id }) {
                JobDetailView(job: job)
            } else {
                ContentUnavailableView(
                    "Select a Stack",
                    systemImage: "folder",
                    description: Text("Choose a stack from the sidebar to view its details.")
                )
            }
        }
        // Shared sheets/alerts for iPad
        .sheet(isPresented: $showJobHistory) {
            JobHistorySheetView(
                deletedJobs: deletedJobs,
                jobToDeletePermanently: $jobToDeletePermanently,
                onDone: { showJobHistory = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { showSettings && !isBetaGlassEnabled },
            set: { if !$0 { showSettings = false } }
        )) {
            SettingsView()
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedItem: selectedItemBinding,
                isPresented: $showColorPicker
            )
            .presentationDetents([.medium])
        }
        .alert("Rename Job", isPresented: $isRenaming) { renameAlertButtons }
        .alert("Confirm Permanent Deletion", isPresented: deletionAlertFlag) {
            deletionAlertButtons
        } message: { Text("This action cannot be undone.") }
        .overlay {
            if showSettings && isBetaGlassEnabled {
                SettingsPanel(isPresented: $showSettings)
                    .zIndex(2)
            }
        }
        .sheet(isPresented: Binding(
            get: { showHelp && !isBetaGlassEnabled },
            set: { if !$0 { showHelp = false } }
        )) {
            HelpView()
        }
        .overlay {
            if showHelp && isBetaGlassEnabled {
                HelpPanel(isPresented: $showHelp)
                    .zIndex(3)
            }
        }
        .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
    }

    // MARK: - Original iPhone list (reused)

    private var jobList: some View {
        List {
            ForEach(jobs, id: \.persistentModelID) { (job: Job) in
                JobRowView(job: job)
                    .contentShape(Rectangle())
                    .onTapGesture { navJob = job }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { startRenaming(job) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                        Button {
                            selectedJob = job
                            showColorPicker = true
                        } label: {
                            Label("Change Color", systemImage: "paintbrush")
                        }
                        .tint(.green)
                    }
                    .swipeActions {
                        Button(role: .destructive) { softDelete(job) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteJob)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var jobHistoryButton: some View {
        if !deletedJobs.isEmpty {
            Button { showJobHistory = true } label: {
                HStack {
                    Text("Stack History").font(.subheadline)
                    Image(systemName: "chevron.right").font(.subheadline)
                }
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Settings") { showSettings = true }
                Button("Help") { showHelp = true }
            } label: {
                Label("Menu", systemImage: "line.horizontal.3")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add Stack", systemImage: "plus") { addJob() }
        }
    }

    // MARK: - Alerts (extracted buttons/bindings)

    private var deletionAlertFlag: Binding<Bool> {
        Binding(
            get: { jobToDeletePermanently != nil },
            set: { if !$0 { jobToDeletePermanently = nil } }
        )
    }

    @ViewBuilder
    private var renameAlertButtons: some View {
        TextField("New Title", text: $newJobTitle)
        Button("Cancel", role: .cancel) {
            isRenaming = false
            jobToRename = nil
            newJobTitle = ""
        }
        Button("Save") {
            if let job = jobToRename {
                job.title = newJobTitle
                try? modelContext.save()
            }
            isRenaming = false
            jobToRename = nil
            newJobTitle = ""
        }
    }

    @ViewBuilder
    private var deletionAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete Permanently", role: .destructive) {
            if let job = jobToDeletePermanently {
                modelContext.delete(job)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Bindings

    private var selectedItemBinding: Binding<Any?> {
        Binding<Any?>(
            get: { selectedJob },
            set: { newValue in
                if let job = newValue as? Job {
                    selectedJob = job
                    job.colorCode = job.colorCode
                    try? modelContext.save()
                } else {
                    selectedJob = nil
                }
            }
        )
    }

    // MARK: - Actions

    private func startRenaming(_ job: Job) {
        jobToRename = job
        newJobTitle = job.title
        isRenaming = true
    }

    private func softDelete(_ job: Job) {
        job.isDeleted = true
        job.deletionDate = Date()
        try? modelContext.save()
    }

    private func addJob() {
        let jobCount = jobs.count + 1
        let newJob = Job(title: "Stack \(jobCount)")
        modelContext.insert(newJob)
        do { try modelContext.save() } catch {
            print("Error saving new stack: \(error)")
        }
    }

    private func deleteJob(at offsets: IndexSet) {
        for offset in offsets {
            let job = jobs[offset]
            job.isDeleted = true
            job.deletionDate = Date()
        }
        try? modelContext.save()
    }
}

// MARK: - iPhone Empty State Bubble

private struct iPhoneEmptyState: View {
    let glassOn: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("Select the + to create a new stack.")
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
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - True Stack Deck Host (Beta-only gate)

@available(iOS 26.0, *)
private struct TrueStackDeckHost: View {
    let jobs: [Job]
    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .opacity(0.08)
                .ignoresSafeArea()
            TrueStackDeckView(jobs: jobs)
        }
    }
}
