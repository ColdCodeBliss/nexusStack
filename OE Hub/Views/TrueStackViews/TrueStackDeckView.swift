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
    @EnvironmentObject private var theme: ThemeManager

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

    // External routes
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

    // Detail routing
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

                // Corner controls + logo (unchanged)
                GeometryReader { g in
                    let isLandscape = g.size.width > g.size.height
                    let isPad = UIDevice.current.userInterfaceIdiom == .pad

                    let safeTop = g.safeAreaInsets.top
                    let safeLeading = g.safeAreaInsets.leading
                    let safeTrailing = g.safeAreaInsets.trailing

                    let buttonSize: CGFloat = 40
                    let half: CGFloat = buttonSize / 2

                    let padLandscapeBumpY: CGFloat = 22

                    let portraitLeftX  = safeLeading + 16 + half
                    let portraitLeftY  = safeTop + 56 + half
                    let portraitRightX = g.size.width - safeTrailing - 16 - half
                    let portraitRightY = portraitLeftY

                    let landscapeLeftX  = safeLeading + 24 + half
                    let landscapeLeftY  = safeTop + 12 + half + ((isPad && isLandscape) ? padLandscapeBumpY : 0)
                    let landscapeRightX = g.size.width - safeTrailing - 24 - half
                    let landscapeRightY = landscapeLeftY

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

                    if (!isLandscape) || isPad {
                        let phonePortraitBump: CGFloat = 12
                        let logoY: CGFloat = (isPad && isLandscape)
                            ? landscapeLeftY
                            : (portraitLeftY + phonePortraitBump)

                        let logoWidth = isPad
                            ? min(g.size.width * 0.12, 100)
                            : min(g.size.width * 0.21, 96)

                        Image("nexusStack_logo")
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

            .task { deck = jobs }

            .onChange(of: geo.size.width) { oldW, newW in
                if abs(newW - oldW) > 1 {
                    lastMeasuredWidth = newW
                    topCardContentHeight = 0
                }
            }

            .onChange(of: topID) {
                topCardContentHeight = 0
            }

            .sheet(item: $activeDetail) { detail in
                JobDetailView(job: detail.job, initialTab: detail.tab)
                    .navigationBarTitleDisplayMode(.inline)
            }

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

        // Theme palette (for optional neon overlay)
        let p = theme.palette(colorScheme)
        
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

        // --- Midnight Neon border + exact-fit "neon tube" (all cards) + misty outer glow ---
        .overlay(alignment: .topLeading) {
            if theme.currentID == .midnightNeon {
                let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
                let w = size.width
                let h = size.height

                // 0) Subtle inset border (unchanged)
                shape
                    .strokeBorder(p.neonAccent.opacity(isBetaGlassEnabled ? 0.24 : 0.32), lineWidth: 1)
                    .frame(width: w, height: h, alignment: .topLeading)

                // 1) "Tube" core — bright line on the edge (unchanged)
                shape
                    .stroke(p.neonAccent.opacity(0.95), lineWidth: 2)
                    .frame(width: w, height: h, alignment: .topLeading)

                // 2) Tight inner glow — hugs the tube (unchanged)
                shape
                    .stroke(p.neonAccent.opacity(0.55), lineWidth: 8)
                    .blur(radius: 6)
                    .mask(
                        shape
                            .inset(by: 8 / 2)
                            .stroke(lineWidth: 8)
                            .frame(width: w, height: h, alignment: .topLeading)
                    )
                    .compositingGroup()
                    .clipShape(shape)
                    .frame(width: w, height: h, alignment: .topLeading)

                // 3) Inner bloom — wider, softer (unchanged)
                shape
                    .stroke(p.neonAccent.opacity(0.28), lineWidth: 18)
                    .blur(radius: 18)
                    .mask(
                        shape
                            .inset(by: 18 / 2)
                            .stroke(lineWidth: 18)
                            .frame(width: w, height: h, alignment: .topLeading)
                    )
                    .compositingGroup()
                    .clipShape(shape)
                    .frame(width: w, height: h, alignment: .topLeading)

                // 4) NEW: Misty OUTER glow that wraps the rim evenly (no alignment change)
                //    Uses zero-offset shadows on a faint stroke so the glow blooms outside.
                //    No clip on this layer so the light can extend off the card.
                let glowColor = color(for: job.effectiveColorIndex)   // glow keyed to card color
                shape
                    .stroke(glowColor.opacity(0.15), lineWidth: 10)    // faint geometry for shadow mask
                    .shadow(color: glowColor.opacity(0.28), radius: 10,  x: 0, y: 0)  // tight aura
                    .shadow(color: glowColor.opacity(0.20), radius: 18, x: 0, y: 0)  // mid bloom
                    .shadow(color: glowColor.opacity(0.12), radius: 30, x: 0, y: 0)  // wide feather
                    .blendMode(.plusLighter)                           // gentle additive feel
                    .frame(width: w, height: h, alignment: .topLeading)
            }
        }


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
        // Disable shadow for Midnight Neon on the top card to avoid any bottom plume
        .shadow(
            color: (theme.currentID == .midnightNeon && isTop) ? Color.clear : Color.black.opacity(isTop ? 0.35 : 0.22),
            radius: (theme.currentID == .midnightNeon && isTop) ? 0 : (isTop ? 20 : 12),
            y: (theme.currentID == .midnightNeon && isTop) ? 0 : (isTop ? 12 : 6)
        )
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            expandedJob = nil
        }
        DispatchQueue.main.async {
            activeDetail = ActiveDetail(job: job, tab: tab)
        }
    }

    // MARK: - Add Job

    private func addJob() {
        let nextIndex = (jobs.count + 1)
        let newJob = Job(title: "Stack \(nextIndex)")
        modelContext.insert(newJob)
        do {
            try modelContext.save()
        } catch {
            print("Error saving new stack: \(error)")
        }
        deck.insert(newJob, at: 0)
    }
}
