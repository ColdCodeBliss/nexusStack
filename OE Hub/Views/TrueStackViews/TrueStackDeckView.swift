//
//  TrueStackDeckView.swift
//  nexusStack / OE Hub
//

import SwiftUI
import SwiftData

// MARK: - Preference key to capture intrinsic content height
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Unified detail routing model
@available(iOS 26.0, *)
private struct ActiveDetail: Identifiable, Equatable {
    let id = UUID()
    let job: Job
    let tab: JobDetailView.DetailTab
}

@available(iOS 26.0, *)
struct TrueStackDeckView: View {
    // Input
    let jobs: [Job]

    // Env
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Feature flags
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false

    // Deck state
    @State private var deck: [Job] = []
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    // Expanded
    @State private var expandedJob: Job? = nil
    @Namespace private var deckNS

    // External routes (unchanged behavior)
    @State private var showGitHub = false
    @State private var showConfluence = false

    // Context
    @State private var showRenameAlert = false
    @State private var pendingRenameText = ""
    @State private var jobForContext: Job? = nil
    @State private var showDeleteConfirm = false

    // Settings / Help
    @State private var showSettings = false
    @State private var showHelp = false

    // NEW: single source of truth for which detail tab to open
    @State private var activeDetail: ActiveDetail? = nil

    // Layout dials
    private let horizontalGutter: CGFloat = 18
    private let maxCardHeight: CGFloat = 560
    private let topHeightRatio: CGFloat = 0.66
    private let stackDepth = 6
    private let layerOffsetY: CGFloat = 18
    private let tiltDegrees: CGFloat = 3.0
    private func scaleForIndex(_ idx: Int) -> CGFloat { max(0.82, 1.0 - CGFloat(idx) * 0.06) }
    private let nonTopOpacity: Double = 0.92
    private let swipeThreshold: CGFloat = 90

    // Dynamic height for the **top** card’s content
    @State private var topCardContentHeight: CGFloat = 0
    @State private var lastMeasuredWidth: CGFloat = 0   // rotation remeasure

    init(jobs: [Job]) { self.jobs = jobs }

    // Convenient “top id” to know when the top card changes
    private var topID: PersistentIdentifier? { deck.first?.persistentModelID }

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let usableHeight = geo.size.height - topInset - bottomInset

            // Base (unscaled) card dimensions
            let baseW = max(280, geo.size.width - (horizontalGutter * 2))
            let baseH = min(usableHeight * topHeightRatio, maxCardHeight)

            // Actual height for the top card = max(baseH, measured), clamped
            let topCardHeight = min(maxCardHeight, max(baseH, topCardContentHeight))

            // Visible stack height
            let visibleCount = min(stackDepth, deck.count)
            let deckHeight = topCardHeight + CGFloat(max(0, visibleCount - 1)) * layerOffsetY

            ZStack {
                LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.02 : 0.06), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    Spacer(minLength: topInset)
                    ZStack {
                        ForEach(Array(deck.prefix(stackDepth).enumerated()), id: \.element.persistentModelID) { (idx, job) in
                            let scale = scaleForIndex(idx)
                            let cardHeight = (idx == 0) ? topCardHeight : (baseH * scale)
                            let cardSize = CGSize(width: baseW * scale, height: cardHeight)
                            card(job: job, index: idx, size: cardSize, baseWidth: baseW, baseHeight: baseH)
                                .offset(y: CGFloat(idx) * layerOffsetY)
                        }
                    }
                    .frame(width: baseW, height: deckHeight, alignment: .center)
                    .padding(.horizontal, horizontalGutter)

                    Spacer(minLength: bottomInset)
                }

                // Expanded overlay (centered)
                if let selected = expandedJob {
                    Color.black.opacity(0.20).ignoresSafeArea().transition(.opacity)
                    TrueStackExpandedView(
                        job: selected,
                        close: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { expandedJob = nil } },
                        openDue:        { openDetail(for: selected, tab: .due) },
                        openChecklist:  { openDetail(for: selected, tab: .checklist) },
                        openMindMap:    { openDetail(for: selected, tab: .mindmap) },
                        openNotes:      { openDetail(for: selected, tab: .notes) },
                        openInfo:       { openDetail(for: selected, tab: .info) },
                        openGitHub:     { showGitHub = true },
                        openConfluence: { showConfluence = true }
                    )
                    .matchedGeometryEffect(id: selected.persistentModelID, in: deckNS)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
                }

                // ──────────────────────────────────────────────────────────────
                // Corner controls + center logo (portrait on iPhone; both on iPad)
                // ──────────────────────────────────────────────────────────────
                GeometryReader { g in
                    let isLandscape = g.size.width > g.size.height
                    let isPad = UIDevice.current.userInterfaceIdiom == .pad

                    // Safe-area edges
                    let safeTop = g.safeAreaInsets.top
                    let safeLeading = g.safeAreaInsets.leading
                    let safeTrailing = g.safeAreaInsets.trailing

                    // Control size (≈40pt total)
                    let buttonSize: CGFloat = 40
                    let half: CGFloat = buttonSize / 2

                    // Tunable iPad landscape bump (you chose 22)
                    let padLandscapeBumpY: CGFloat = 22

                    // Portrait positions
                    let portraitLeftX  = safeLeading + 16 + half
                    let portraitLeftY  = safeTop + 56 + half
                    let portraitRightX = g.size.width - safeTrailing - 16 - half
                    let portraitRightY = portraitLeftY

                    // Landscape positions (+ optional iPad bump)
                    let landscapeLeftX  = safeLeading + 24 + half
                    let landscapeLeftY  = safeTop + 12 + half + ((isPad && isLandscape) ? padLandscapeBumpY : 0)
                    let landscapeRightX = g.size.width - safeTrailing - 24 - half
                    let landscapeRightY = landscapeLeftY

                    // Hamburger (Settings / Help)
                    Menu {
                        Button("Settings") { showSettings = true }
                        Button("Help")     { showHelp = true }
                    } label: {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                Group {
                                    if #available(iOS 26.0, *), isBetaGlassEnabled {
                                        Color.clear.glassEffect(.regular, in: .circle)
                                    } else {
                                        Circle().fill(.ultraThinMaterial)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: isLandscape ? landscapeLeftX  : portraitLeftX,
                        y: isLandscape ? landscapeLeftY  : portraitLeftY
                    )

                    // ➕ Add Job
                    Button {
                        addJob()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(
                                Group {
                                    if #available(iOS 26.0, *), isBetaGlassEnabled {
                                        Color.clear.glassEffect(.regular, in: .circle)
                                    } else {
                                        Circle().fill(.ultraThinMaterial)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: isLandscape ? landscapeRightX : portraitRightX,
                        y: isLandscape ? landscapeRightY : portraitRightY
                    )

                    // Center logo (portrait on iPhone; both orientations on iPad)
                    if (!isLandscape) || isPad {
                        let phonePortraitBump: CGFloat = 12
                        let logoY: CGFloat = (isPad && isLandscape)
                            ? landscapeLeftY             // includes iPad bump
                            : (portraitLeftY + phonePortraitBump)

                        let logoWidth = isPad
                            ? min(g.size.width * 0.12, 100)
                            : min(g.size.width * 0.21, 96)

                        Image("nexusStack_logo")        // Any/Dark variants are handled in the asset
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoWidth)
                            .position(x: g.size.width / 2, y: logoY)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .zIndex(2)
                    }
                }
                .ignoresSafeArea()
            }

            // Initialize deck
            .task { deck = jobs }

            // Re-measure on width changes (rotation)
            .onChange(of: geo.size.width) { oldW, newW in
                if abs(newW - oldW) > 1 {
                    lastMeasuredWidth = newW
                    topCardContentHeight = 0
                }
            }

            // Re-measure when the top card changes
            .onChange(of: topID) {
                topCardContentHeight = 0
            }

            // ROUTES
            // Single detail sheet that honors the initial tab on first open
            .sheet(item: $activeDetail) { detail in
                JobDetailView(job: detail.job, initialTab: detail.tab)
                    .navigationBarTitleDisplayMode(.inline)
            }

            // External full-screen views (unchanged)
            .fullScreenCover(isPresented: $showGitHub) {
                if let j = expandedJob {
                    GitHubBrowserView(recentKey: "recentRepos.\(j.repoBucketKey)")
                }
            }
            .fullScreenCover(isPresented: $showConfluence) {
                if let j = expandedJob {
                    ConfluenceLinksView(storageKey: "confluenceLinks.\(j.repoBucketKey)", maxLinks: 5)
                }
            }

            // Settings / Help
            .sheet(isPresented: Binding(
                get: { showSettings && !isBetaGlassEnabled },
                set: { if !$0 { showSettings = false } }
            )) { SettingsView() }
            .overlay {
                if showSettings && isBetaGlassEnabled {
                    SettingsPanel(isPresented: $showSettings).zIndex(20)
                }
            }
            .sheet(isPresented: Binding(
                get: { showHelp && !isBetaGlassEnabled },
                set: { if !$0 { showHelp = false } }
            )) { HelpView() }
            .overlay {
                if showHelp && isBetaGlassEnabled {
                    HelpPanel(isPresented: $showHelp).zIndex(20)
                }
            }

            // Alerts
            .alert("Rename Stack", isPresented: $showRenameAlert) {
                TextField("Title", text: $pendingRenameText)
                Button("Cancel", role: .cancel) { jobForContext = nil }
                Button("Save") {
                    if let j = jobForContext {
                        j.title = pendingRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                    }
                    jobForContext = nil
                }
            }
            .alert("Delete Stack", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let j = jobForContext {
                        modelContext.delete(j)
                        try? modelContext.save()
                        removeFromDeck(j)
                    }
                    jobForContext = nil
                }
            } message: { Text("This action cannot be undone.") }
        }
    }

    // MARK: - Card

    private func card(job: Job, index idx: Int, size: CGSize, baseWidth: CGFloat, baseHeight: CGFloat) -> some View {
        let isTop = idx == 0
        let tiltSign: CGFloat = (idx % 2 == 0) ? 1 : -1

        let drag = DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isTop, expandedJob == nil else { return }
                isDragging = true
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard isTop, expandedJob == nil else { return }
                isDragging = false
                let x = value.translation.width
                if abs(x) > swipeThreshold {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sendTopCardToBack()
                        dragTranslation = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        dragTranslation = 0
                    }
                }
            }

        // Content (intrinsic height for top card)
        let content = VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text("Created \(tsFormattedDate(job.creationDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            Divider().opacity(0.12)

            infoGrid(for: job)
                .font(.subheadline)
        }
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: size.width, alignment: .topLeading)
        .id(isTop ? "topW-\(Int(size.width))-\(job.persistentModelID.hashValue)" : "\(job.persistentModelID.hashValue)")
        .background(
            GeometryReader { gp in
                Color.clear.preference(key: ViewHeightKey.self, value: isTop ? gp.size.height : 0)
            }
        )

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .frame(width: size.width, height: size.height)
                .glassEffect(
                    .regular.tint(color(for: job.effectiveColorIndex).opacity(isTop ? 0.50 : 0.42)),
                    in: .rect(cornerRadius: 22)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(isTop ? 0.08 : 0.05), lineWidth: 1)
                )

            content

            if isTop && expandedJob == nil {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            expandedJob = job
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            jobForContext = job
                            pendingRenameText = job.title
                            showRenameAlert = true
                        }
                    )
                    .contextMenu {
                        Button("Rename") {
                            jobForContext = job
                            pendingRenameText = job.title
                            showRenameAlert = true
                        }
                        Button("Change Color") { cycleColor(job) }
                        Button("Delete", role: .destructive) {
                            jobForContext = job
                            showDeleteConfirm = true
                        }
                    }
            }
        }
        .mask(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipped()
        .animation(nil, value: topCardContentHeight)

        .opacity(isTop ? 1.0 : nonTopOpacity)
        .matchedGeometryEffect(id: job.persistentModelID, in: deckNS)
        .rotationEffect(.degrees(isTop ? 0 : Double(tiltSign) * Double(tiltDegrees)))
        .offset(x: isTop ? dragTranslation : 0)
        .gesture(isTop ? drag : nil)
        .zIndex(Double(stackDepth - idx))
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: dragTranslation)
        .onPreferenceChange(ViewHeightKey.self) { h in
            if isTop, h > 0 {
                withAnimation(.none) { topCardContentHeight = h }
            }
        }
        .shadow(color: .black.opacity(isTop ? 0.35 : 0.22),
                radius: isTop ? 20 : 12, y: isTop ? 12 : 6)
    }

    // MARK: - Info grid

    @ViewBuilder
    private func infoGrid(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("Email", job.email)
            infoRow("Pay Rate", payString(rate: job.payRate, type: job.compensation))
            infoRow("Manager", job.managerName)
            infoRow("Role / Title", job.roleTitle)
            infoRow("Equipment", job.equipmentList)
            infoRow("Job Type", job.type.rawValue + (job.contractEndDate.map { "  •  Ends \(tsFormattedDate($0))" } ?? ""))
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).foregroundStyle(.secondary)
                Text(trimmed)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func payString(rate: Double, type: Job.PayType) -> String? {
        guard rate > 0 else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        let amount = f.string(from: NSNumber(value: rate)) ?? "\(rate)"
        let period = (type == .hourly) ? "/hr" : "/yr"
        return "\(amount)\(period)"
    }

    // MARK: - Deck ops

    private func sendTopCardToBack() {
        guard let first = deck.first else { return }
        deck.removeFirst()
        deck.append(first)
    }

    private func removeFromDeck(_ job: Job) {
        deck.removeAll { $0.persistentModelID == job.persistentModelID }
    }

    private func cycleColor(_ job: Job) {
        job.cycleColorForward()
        try? modelContext.save()
    }

    // MARK: - Routing helper

    private func openDetail(for job: Job, tab: JobDetailView.DetailTab) {
        // Close the expanded panel and open the requested tab on the detail sheet.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            expandedJob = nil
        }
        // Set the item AFTER closing to avoid animation conflicts.
        // Dispatch to next runloop ensures the sheet reads the correct initial tab on first presentation.
        DispatchQueue.main.async {
            activeDetail = ActiveDetail(job: job, tab: tab)
        }
    }

    // MARK: - Add Job (mirrors HomeView behavior)

    private func addJob() {
        let nextIndex = (jobs.count + 1)
        let newJob = Job(title: "Stack \(nextIndex)")
        modelContext.insert(newJob)
        do {
            try modelContext.save()
        } catch {
            print("Error saving new stack: \(error)")
        }
        // Make it feel instant in this view as well:
        deck.insert(newJob, at: 0)
    }
}
