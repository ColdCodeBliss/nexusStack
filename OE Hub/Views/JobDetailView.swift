import SwiftUI
import SwiftData

struct JobDetailView: View {
    // State that drives child tabs
    @State private var newTaskDescription: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newChecklistItem: String = ""
    @State private var isCompletedSectionExpanded: Bool = false

    enum DetailTab: Hashable { case due, checklist, mindmap, notes, info }
    @State private var selection: DetailTab = .due

    // Triggers for top-right "+" buttons
    @State private var addDeliverableTrigger: Int = 0
    @State private var addNoteTrigger: Int = 0
    @State private var addChecklistTrigger: Int = 0

    // Sheets
    @State private var showGitHubBrowser: Bool = false
    @State private var showConfluenceSheet: Bool = false
    @State private var showHelpPanel: Bool = false


    // Style toggles
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var job: Job

    // 🔒 Keep the caller’s tab around and apply it exactly once.
    private let startTab: DetailTab
    @State private var appliedInitial = false

    init(job: Job, initialTab: DetailTab = .due) {
        self.job = job
        self.startTab = initialTab
        _selection = State(initialValue: initialTab) // start on the requested tab
    }

    var body: some View {
        content
            .navigationTitle(job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { trailingButton }
            }
            // Make sure the initial tab is applied exactly once on presentation.
            .onAppear {
                if !appliedInitial {
                    selection = startTab
                    appliedInitial = true
                }
            }

            // GitHub: sheet for Standard, full-screen overlay for Beta glass
            .sheet(isPresented: Binding(
                get: { !isBetaGlassEnabled && showGitHubBrowser },
                set: { if !$0 { showGitHubBrowser = false } }
            )) {
                GitHubBrowserView(recentKey: "recentRepos.\(job.repoBucketKey)")
            }
            .fullScreenCover(isPresented: Binding(
                get: { isBetaGlassEnabled && showGitHubBrowser },
                set: { if !$0 { showGitHubBrowser = false } }
            )) {
                GitHubBrowserView(recentKey: "recentRepos.\(job.repoBucketKey)")
            }

            .fullScreenCover(isPresented: $showConfluenceSheet) {
                ConfluenceLinksView(
                    storageKey: "confluenceLinks.\(job.repoBucketKey)",
                    maxLinks: 5
                )
            }
        
            .sheet(isPresented: Binding(
                get: { showHelpPanel && !isBetaGlassEnabled },
                set: { if !$0 { showHelpPanel = false } }
            )) { HelpView() }
            .overlay {
                if showHelpPanel && isBetaGlassEnabled {
                    HelpPanel(isPresented: $showHelpPanel).zIndex(20)
                }
            }

    }

    // MARK: - Split main content

    @ViewBuilder
    private var content: some View {
        TabView(selection: $selection) {
            dueTab
            checklistTab
            mindmapTab
            notesTab
            infoTab
        }
        // 🆔 Encourage SwiftUI to rebuild tab presentation when the caller’s
        // requested initial tab changes between openings.
        .id(startTab)
    }

    // MARK: - Individual tabs

    private var dueTab: some View {
        DueTabView(
            newTaskDescription: $newTaskDescription,
            newDueDate: $newDueDate,
            isCompletedSectionExpanded: $isCompletedSectionExpanded,
            addDeliverableTrigger: $addDeliverableTrigger,
            job: job
        )
        .tabItem { Label("Due", systemImage: "calendar") }
        .tag(DetailTab.due)
    }

    private var checklistTab: some View {
        ChecklistsTabView(
            newChecklistItem: $newChecklistItem,
            addChecklistTrigger: $addChecklistTrigger,
            job: job
        )
        .tabItem { Label("Checklist", systemImage: "checkmark.square") }
        .tag(DetailTab.checklist)
    }

    private var mindmapTab: some View {
        MindMapTabView(job: job)
            .tabItem { Label("Mind Map", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
            .tag(DetailTab.mindmap)
    }

    private var notesTab: some View {
        NotesTabView(
            addNoteTrigger: $addNoteTrigger,
            job: job
        )
        .tabItem { Label("Notes", systemImage: "note.text") }
        .tag(DetailTab.notes)
    }

    private var infoTab: some View {
        InfoTabView(job: job)
            .tabItem { Label("Info", systemImage: "info.circle") }
            .tag(DetailTab.info)
    }

    // MARK: - Trailing toolbar button(s)

    @ViewBuilder
    private var trailingButton: some View {
        switch selection {
        // Replace the old "Add ..." buttons with a single glassy Help button
        case .due, .notes, .checklist:
            Button {
                showHelpPanel = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.headline)
                    .padding(8)
            }
            .background(toolbarPillBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(isBetaGlassEnabled ? 0.10 : 0), lineWidth: 1)
            )
            .accessibilityLabel("Open Help")

        case .info:
            // Keep Info's existing Confluence + GitHub pair
            HStack(spacing: 10) {
                toolbarIconButton(assetName: "Confluence_icon", accessibility: "Open Confluence") {
                    showConfluenceSheet = true
                }
                toolbarIconButton(assetName: "github", accessibility: "Open GitHub Browser") {
                    showGitHubBrowser = true
                }
            }

        default:
            EmptyView()
        }
    }


    // MARK: - Toolbar helpers (glassy icon pill)

    private func toolbarIconButton(assetName: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .padding(8)
                .accessibilityLabel(accessibility)
        }
        .background(toolbarPillBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(isBetaGlassEnabled ? 0.10 : 0), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var toolbarPillBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Color.clear
        }
    }
}
