import SwiftUI
import SwiftData
import UIKit

struct MindMapTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager          // ⬅️ THEME
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    var job: Job

    private let canvasSize: CGFloat = 3000
    private var canvasCenter: CGPoint { CGPoint(x: canvasSize/2, y: canvasSize/2) }

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selected: MindNode?

    @State private var viewSize: CGSize = .zero
    @State private var scaleBase: CGFloat = 1.0
    
    // Track starting values for gestures
    @State private var panStart: CGSize = .zero
    @State private var nodeDragStart: [UUID: CGPoint] = [:]

    private let childRadius: CGFloat = 220
    private let nodeColorOptions: [String] = ["red","blue","green","yellow","orange","purple","brown","teal","gray", "black", "white"]

    @State private var showClearConfirm = false
    @State private var isTopToolbarCollapsed = false
    @State private var showAutoArrangeConfirm = false

    @FocusState private var focusedNodeID: UUID?
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var isLandscape: Bool { viewSize.width > viewSize.height }

    /// How far the whole toolbar slides right when collapsed
    private var slideDistance: CGFloat {
        if isPad && isLandscape { return 134 }
        return isLandscape ? 156 : 94
    }

    /// Right padding when expanded (positive pulls inward, negative pushes off-screen)
    private var expandedTrailingPad: CGFloat {
        if isPad && isLandscape { return 12 }
        return isLandscape ? -55 : 9
    }

    /// Right padding when collapsed
    private var collapsedTrailingPad: CGFloat {
        if isPad && isLandscape { return 0 }
        return isLandscape ? -40 : -40
    }

    // ✅ Share state: present sheet only when we have a URL
    private struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    @State private var shareItem: ShareItem? = nil

    // 🌙 Midnight Neon — shared flicker for all node bubbles in this screen
    @State private var neonFlicker: Double = 1.0
    @State private var flickerArmed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selected = nil
                        focusedNodeID = nil
                    }

                mapContent
                    .frame(width: canvasSize, height: canvasSize)
                    .offset(offset)
                    .scaleEffect(scale, anchor: .topLeading)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
                    .animation(.interactiveSpring(), value: scale)
                    .animation(.interactiveSpring(), value: offset)
            }
            .onAppear {
                viewSize = geo.size
                ensureRoot()

                if let root = job.mindNodes.first(where: { $0.isRoot }) {
                    center(on: CGPoint(x: root.x, y: root.y))
                } else {
                    center(on: canvasCenter)
                }

                DispatchQueue.main.async {
                    panStart = offset
                }
            }
            .onChange(of: scale) { _, _ in
                panStart = offset
            }
        }
        .navigationTitle("Mind Map")

        .safeAreaInset(edge: .bottom) {
            controlsBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }

        // Top-right overlay (wand, trash, share)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isTopToolbarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isTopToolbarCollapsed ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .padding(6)
                .background(topButtonBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .accessibilityLabel(isTopToolbarCollapsed ? "Show tools" : "Hide tools")

                HStack(spacing: 6) {
                    Button { showAutoArrangeConfirm = true } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }

                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Clear Mind Map")

                    // ✅ Share (export PDF)
                    Button { shareMindMap() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Share Mind Map")
                }
                .padding(6)
                .background(topButtonBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            }
            .offset(x: isTopToolbarCollapsed ? slideDistance : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isTopToolbarCollapsed)
            .padding(.trailing, isTopToolbarCollapsed ? collapsedTrailingPad : expandedTrailingPad)
            .padding(.top, 8)
        }

        // Glass confirmation overlay (Beta only)
        .overlay {
            if showAutoArrangeConfirm && isBetaGlassEnabled {
                AutoArrangeConfirmPanel(
                    isPresented: $showAutoArrangeConfirm,
                    isBeta: isBetaGlassEnabled,
                    onConfirm: { autoArrangeTree() }
                )
                .zIndex(3)
            }
        }

        // Fallback system alert when Beta OFF
        .alert(
            "Re-arrange Mind Map?",
            isPresented: Binding(
                get: { showAutoArrangeConfirm && !isBetaGlassEnabled },
                set: { if !$0 { showAutoArrangeConfirm = false } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Re-arrange", role: .destructive) { autoArrangeTree() }
        } message: {
            Text("This will re-arrange the entire map and is not reversible.")
        }

        // Clear alert (unchanged)
        .alert("Clear Mind Map?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { clearMindMap() }
        } message: {
            Text("This will permanently delete all nodes. This action cannot be undone.")
        }

        // ✅ Present only when we actually have a URL to share
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.url])
                .ignoresSafeArea()
        }

        // Neon flicker lifecycle
        .onAppear { armFlickerIfNeeded() }
        .onDisappear { flickerArmed = false }
        .onChange(of: theme.currentID) { _, _ in armFlickerIfNeeded() }
    }

    // MARK: - Live map (interactive)
    private var mapContent: some View {
        ZStack {
            // edges
            Canvas { ctx, _ in
                let neonOn = (theme.currentID == .midnightNeon)
                let accent = theme.palette(colorScheme).neonAccent

                for node in job.mindNodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)

                    if neonOn {
                        strokeEdgeNeon(&ctx, from: p1, to: p2, accent: accent, neonFlicker: neonFlicker)
                    } else {
                        var path = Path()
                        let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                        path.move(to: p1)
                        path.addQuadCurve(to: p2, control: mid)
                        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                        ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                    }
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = nil
                    focusedNodeID = nil
                }

            // nodes
            ForEach(job.mindNodes) { node in
                NodeBubble(
                    node: node,
                    isSelected: node.id == selected?.id,
                    glassOn: isBetaGlassEnabled,
                    focused: $focusedNodeID,
                    neonFlicker: neonFlicker                  // ⬅️ pass flicker
                )
                .environmentObject(theme)                      // ⬅️ pass theme
                .position(x: node.x, y: node.y)
                .highPriorityGesture(nodeDragGesture(for: node))
                .onTapGesture { selected = node }
            }
        }
        .background(Color.clear)
        .clipped()
    }

    // MARK: - Snapshot map (read-only, used for PDF export)
    private var snapshotContent: some View {
        ZStack {
            Canvas { ctx, _ in
                let neonOn = (theme.currentID == .midnightNeon)
                let accent = theme.palette(colorScheme).neonAccent

                for node in job.mindNodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)

                    if neonOn {
                        // Use a slightly lower base opacity for export so lines don’t overpower nodes
                        strokeEdgeNeon(&ctx, from: p1, to: p2, accent: accent, baseOpacity: 0.22, neonFlicker: neonFlicker)
                    } else {
                        var path = Path()
                        let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                        path.move(to: p1)
                        path.addQuadCurve(to: p2, control: mid)
                        let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                        ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                    }
                }
            }


            ForEach(job.mindNodes) { node in
                NodeBubbleSnapshot(
                    node: node,
                    glassOn: isBetaGlassEnabled,
                    neonFlicker: neonFlicker                   // ⬅️ match export
                )
                .environmentObject(theme)
                .position(x: node.x, y: node.y)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .background(Color.clear)
    }

    // MARK: - Bottom controls
    private var controlsBar: some View {
        HStack(spacing: 10) {
            Button { zoom(by: -0.15) } label: { controlIcon("minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: [.command])

            Button { zoom(by:  0.15) } label: { controlIcon("plus.magnifyingglass") }
                .keyboardShortcut("=", modifiers: [.command])

            Button { centerOnRoot() } label: { controlIcon("target") }
                .keyboardShortcut("0", modifiers: [.command])

            Button { addChild() }       label: { controlIcon("plus") }

            if let s = selected, !s.isRoot {
                Button(role: .destructive) { deleteSelected() } label: { controlIcon("trash") }
            }

            if let s = selected {
                Button { toggleComplete(s) } label: {
                    controlIcon(s.isCompleted ? "checkmark.circle.fill" : "circle")
                }

                Menu {
                    ForEach(nodeColorOptions, id: \.self) { code in
                        Button {
                            s.colorCode = code
                            try? modelContext.save()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: code))
                                    .frame(width: 14, height: 14)
                                Text(code.capitalized)
                            }
                        }
                    }
                } label: {
                    controlIcon("paintpalette")
                }
            }
        }
        .padding(10)
        .background(controlsBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    @ViewBuilder private var controlsBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private var topButtonBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }

    // MARK: - Gestures / actions
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let sensitivity: CGFloat = 0.25
                let dx = (value.translation.width  * sensitivity) / max(scale, 0.001)
                let dy = (value.translation.height * sensitivity) / max(scale, 0.001)
                offset = CGSize(width: panStart.width + dx,
                                height: panStart.height + dy)
            }
            .onEnded { _ in
                panStart = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = clamp(scaleBase * value, min: 0.4, max: 3.0)
            }
            .onEnded { _ in
                scaleBase = clamp(scale, min: 0.4, max: 3.0)
            }
    }

    private func nodeDragGesture(for node: MindNode) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if nodeDragStart[node.id] == nil {
                    nodeDragStart[node.id] = CGPoint(x: node.x, y: node.y)
                }
                let start = nodeDragStart[node.id]!

                let sensitivity: CGFloat = 0.35
                let dx = (v.translation.width  * sensitivity) / max(scale, 0.001)
                let dy = (v.translation.height * sensitivity) / max(scale, 0.001)

                node.x = Double(start.x + dx).clamped(to: 0...canvasSize)
                node.y = Double(start.y + dy).clamped(to: 0...canvasSize)
            }
            .onEnded { _ in
                nodeDragStart[node.id] = nil
                try? modelContext.save()
            }
    }

    private func ensureRoot() {
        if job.mindNodes.contains(where: { $0.isRoot }) { return }
        let root = MindNode(title: job.title.isEmpty ? "Central Idea" : job.title,
                            x: Double(canvasCenter.x),
                            y: Double(canvasCenter.y),
                            colorCode: "teal",
                            isRoot: true)
        root.job = job
        job.mindNodes.append(root)
        try? modelContext.save()
        selected = root
    }

    private func centerOnRoot() {
        if let root = job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: root.x, y: root.y))
        }
    }

    private func center(on p: CGPoint) {
        guard viewSize != .zero else { return }
        withAnimation(.spring()) {
            let viewCenter = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
            offset = CGSize(width: viewCenter.x / scale - p.x,
                            height: viewCenter.y / scale - p.y)
        }
    }

    private func addChild() {
        guard let anchor = selected ?? job.mindNodes.first(where: { $0.isRoot }) else { return }
        let count = max(0, anchor.children.count)
        let angle = CGFloat(count) * (.pi / 3.0)
        let dx = cos(angle) * childRadius
        let dy = sin(angle) * childRadius
        let child = MindNode(title: "New Node",
                             x: anchor.x + Double(dx),
                             y: anchor.y + Double(dy),
                             colorCode: anchor.colorCode ?? "teal")
        child.job = job
        child.parent = anchor
        anchor.children.append(child)
        job.mindNodes.append(child)
        try? modelContext.save()
        selected = child
    }

    private func deleteSelected() {
        guard let node = selected, !node.isRoot else { return }
        if let parent = node.parent {
            for c in node.children {
                c.parent = parent
                parent.children.append(c)
            }
        }
        modelContext.delete(node)
        try? modelContext.save()
        selected = nil
    }

    private func toggleComplete(_ node: MindNode) {
        node.isCompleted.toggle()
        try? modelContext.save()
    }

    private func zoom(by delta: CGFloat) {
        scale = clamp(scale + delta, min: 0.4, max: 3.0)
        scaleBase = scale
        if let focus = selected ?? job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: focus.x, y: focus.y))
        }
    }

    private func clearMindMap() {
        for n in job.mindNodes { modelContext.delete(n) }
        job.mindNodes.removeAll()
        try? modelContext.save()
        selected = nil
        scale = 1.0
        scaleBase = 1.0
        center(on: canvasCenter)
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }

    // MARK: - Export & Share

    private func shareMindMap() {
        if let url = exportMindMapPDF(maxDimension: 2200) {
            shareItem = ShareItem(url: url)
        } else {
            print("⚠️ Mind map export failed; no file to share.")
        }
    }

    /// Renders a **read-only** snapshot (no TextFields) to PDF and writes to a temp file.
    private func exportMindMapPDF(maxDimension: CGFloat = 2200) -> URL? {
        let exportSide = min(canvasSize, maxDimension)
        let scaleFactor = exportSide / canvasSize
        let fullSize = CGSize(width: canvasSize, height: canvasSize)

        let exportView = snapshotContent
            .frame(width: fullSize.width, height: fullSize.height)
            .background(Color.clear)

        let swiftUIRenderer = ImageRenderer(content: exportView)
        swiftUIRenderer.scale = Double(scaleFactor)

        var snapshot: UIImage? = swiftUIRenderer.uiImage

        if snapshot == nil {
            let host = UIHostingController(rootView: exportView)
            host.view.bounds = CGRect(origin: .zero, size: fullSize)
            host.view.backgroundColor = .clear
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let renderer = UIGraphicsImageRenderer(size: fullSize)
            snapshot = renderer.image { ctx in
                host.view.layer.render(in: ctx.cgContext)
            }

            if scaleFactor != 1.0, let img = snapshot {
                let scaledSize = CGSize(width: fullSize.width * scaleFactor, height: fullSize.height * scaleFactor)
                let scaledRenderer = UIGraphicsImageRenderer(size: scaledSize)
                snapshot = scaledRenderer.image { _ in
                    img.draw(in: CGRect(origin: .zero, size: scaledSize))
                }
            }
        }

        guard let image = snapshot else { return nil }

        let pageRect = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        let pdfData = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: pageRect)
        }

        let base = job.title.isEmpty ? "MindMap" : job.title
        let safe = base.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe)_MindMap.pdf")

        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            print("PDF write error: \(error)")
            return nil
        }
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

// === AutoArrangeConfirmPanel, NodeBubble, NodeBubbleSnapshot, ActivityView remain, but NodeBubble/Snapshot gain Neon overlay ===

private extension MindMapTabView {
    func autoArrangeTree() {
        guard let root = job.mindNodes.first(where: { $0.isRoot }) else { return }

        let leaves = leafCount(root)
        let levels = max(1, treeDepth(root))

        let baseNodeSpacing: CGFloat = 260
        let baseLevelGap: CGFloat    = 200

        let maxUsableWidth = canvasSize * 0.85
        let neededWidth = CGFloat(max(1, leaves - 1)) * baseNodeSpacing
        let widthScale = neededWidth > maxUsableWidth ? (maxUsableWidth / neededWidth) : 1.0
        let nodeSpacing = max(160, baseNodeSpacing * widthScale)

        let maxUsableHeight = canvasSize * 0.85
        let neededHeight = CGFloat(max(0, levels - 1)) * baseLevelGap
        let heightScale = neededHeight > maxUsableHeight ? (maxUsableHeight / neededHeight) : 1.0
        let levelGap = max(140, baseLevelGap * heightScale)

        var nextX: CGFloat = 0
        func assignPositions(_ node: MindNode, level: Int) {
            if node.children.isEmpty {
                nextX += nodeSpacing
                node.x = Double(nextX)
            } else {
                for c in node.children { assignPositions(c, level: level + 1) }
                if let first = node.children.first, let last = node.children.last {
                    let fx = CGFloat(first.x)
                    let lx = CGFloat(last.x)
                    node.x = Double((fx + lx) / 2.0)
                } else {
                    nextX += nodeSpacing
                    node.x = Double(nextX)
                }
            }
            node.y = Double(CGFloat(level) * levelGap)
        }

        nextX = 0
        assignPositions(root, level: 0)

        let xs = job.mindNodes.map { CGFloat($0.x) }
        let ys = job.mindNodes.map { CGFloat($0.y) }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let width = maxX - minX
        let height = maxY - minY
        let centerX = minX + width/2
        let centerY = minY + height/2
        let dx = canvasCenter.x - centerX
        let dy = canvasCenter.y - centerY

        for n in job.mindNodes {
            n.x = Double(CGFloat(n.x) + dx)
            n.y = Double(CGFloat(n.y) + dy)
        }

        try? modelContext.save()
        selected = root
        center(on: CGPoint(x: root.x, y: root.y))
    }

    func leafCount(_ node: MindNode) -> Int {
        if node.children.isEmpty { return 1 }
        return node.children.reduce(0) { $0 + leafCount($1) }
    }

    func treeDepth(_ node: MindNode) -> Int {
        if node.children.isEmpty { return 1 }
        return 1 + node.children.map(treeDepth(_:)).max()!
    }
}

// MARK: - Glass confirmation bubble (Beta or fallback)
private struct AutoArrangeConfirmPanel: View {
    @Binding var isPresented: Bool
    var isBeta: Bool
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 14) {
                Text("Re-arrange Mind Map?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("This will re-arrange the entire map and is not reversible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        withAnimation { isPresented = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Re-arrange") {
                        onConfirm()
                        withAnimation { isPresented = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isPresented)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBeta {
            ZStack {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

// MARK: - Live node bubble (editable) + Neon
private struct NodeBubble: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager
    var node: MindNode
    var isSelected: Bool
    var glassOn: Bool
    var focused: FocusState<UUID?>.Binding
    var neonFlicker: Double                              // ⬅️ from parent

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let bubbleWidth: CGFloat = 220
    private let minBubbleHeight: CGFloat = 52
    private let radius: CGFloat = 16
    private let titleFont: Font = .callout.weight(.semibold)
    private let hPad: CGFloat = 10
    private let vPad: CGFloat = 8

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")
        let neonOn = theme.currentID == .midnightNeon

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)
                    .onTapGesture { node.isCompleted.toggle(); try? modelContext.save() }

                TextField("Idea", text: binding(\.title))
                    .textFieldStyle(.plain)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused(focused, equals: node.id)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: minBubbleHeight, alignment: .leading)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) :
                                      (glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20)),
                        lineWidth: isSelected ? 2 : 1)
        )
        // 🌙 Midnight Neon tube+glow over the bubble
        .overlay(neonOverlayNode(radius: radius, neonFlicker: neonFlicker))
        // Suppress legacy shadow when Neon is active (avoids plumes)
        .shadow(color: neonOn ? .clear : (glassOn ? .black.opacity(0.25) : .black.opacity(0.15)),
                radius: neonOn ? 0 : (glassOn ? 12 : 5),
                x: 0, y: neonOn ? 0 : (glassOn ? 7 : 0))
    }

    @ViewBuilder
    private func nodeBackground(tint: Color) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            // Standard (non-Beta): solid tint gradient bubble
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<MindNode, T>) -> Binding<T> {
        Binding(
            get: { node[keyPath: keyPath] },
            set: { node[keyPath: keyPath] = $0; try? modelContext.save() }
        )
    }

    // Concrete overlay to avoid generic inference issues
    private func neonOverlayNode(radius: CGFloat, neonFlicker: Double) -> some View {
        guard theme.currentID == .midnightNeon else { return AnyView(EmptyView()) }

        let p = theme.palette(Environment(\.colorScheme).wrappedValue)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        let borderAlpha    = isBetaGlassEnabled ? 0.24 : 0.32
        let tubeAlpha      = isBetaGlassEnabled ? 0.55 : 0.65
        let innerGlowAlpha = isBetaGlassEnabled ? 0.22 : 0.28
        let bloomAlpha     = isBetaGlassEnabled ? 0.14 : 0.20

        let overlay = ZStack {
            shape.strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)

            shape.stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 2))

            shape.stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 8)
                .blur(radius: 9)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 10))

            shape.stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 14)
                .blur(radius: 16)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 16))
        }
        return AnyView(overlay)
    }
}

// MARK: - Snapshot node bubble (read-only label) + Neon
private struct NodeBubbleSnapshot: View {
    @EnvironmentObject private var theme: ThemeManager
    var node: MindNode
    var glassOn: Bool
    var neonFlicker: Double

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let bubbleWidth: CGFloat = 220
    private let minBubbleHeight: CGFloat = 52
    private let radius: CGFloat = 16
    private let titleFont: Font = .callout.weight(.semibold)
    private let hPad: CGFloat = 10
    private let vPad: CGFloat = 8

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")
        let neonOn = theme.currentID == .midnightNeon

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)

                Text(node.title.isEmpty ? "Idea" : node.title)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: minBubbleHeight, alignment: .leading)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
        )
        .overlay(neonOverlayNode(radius: radius, neonFlicker: neonFlicker))
        .shadow(color: neonOn ? .clear : (glassOn ? .black.opacity(0.25) : .black.opacity(0.15)),
                radius: neonOn ? 0 : (glassOn ? 12 : 5),
                x: 0, y: neonOn ? 0 : (glassOn ? 7 : 0))
    }

    @ViewBuilder
    private func nodeBackground(tint: Color) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }

    private func neonOverlayNode(radius: CGFloat, neonFlicker: Double) -> some View {
        guard theme.currentID == .midnightNeon else { return AnyView(EmptyView()) }

        let p = theme.palette(Environment(\.colorScheme).wrappedValue)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        let borderAlpha    = isBetaGlassEnabled ? 0.24 : 0.32
        let tubeAlpha      = isBetaGlassEnabled ? 0.55 : 0.65
        let innerGlowAlpha = isBetaGlassEnabled ? 0.22 : 0.28
        let bloomAlpha     = isBetaGlassEnabled ? 0.14 : 0.20

        let overlay = ZStack {
            shape.strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)

            shape.stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 2))

            shape.stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 8)
                .blur(radius: 9)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 10))

            shape.stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 14)
                .blur(radius: 16)
                .blendMode(.plusLighter)
                .mask(shape.stroke(lineWidth: 16))
        }
        return AnyView(overlay)
    }
}

// MARK: - Neon edge stroker (used by live & snapshot canvases)
private func strokeEdgeNeon(
    _ ctx: inout GraphicsContext,
    from p1: CGPoint,
    to p2: CGPoint,
    accent: Color,
    baseOpacity: Double = 0.28,
    neonFlicker: Double
) {
    // Shared path + base stroke
    var path = Path()
    let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
    path.move(to: p1)
    path.addQuadCurve(to: p2, control: mid)

    let baseStyle = StrokeStyle(lineWidth: 2, lineCap: .round)
    ctx.stroke(path, with: .color(.primary.opacity(baseOpacity)), style: baseStyle)

    // Neon layers (contained in a layer so filters don't leak)
    ctx.drawLayer { layer in
        // Core
        layer.stroke(path,
                     with: .color(accent.opacity(0.70 * neonFlicker)),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Tight glow
        layer.addFilter(.shadow(color: accent.opacity(0.55 * neonFlicker), radius: 6, x: 0, y: 0))
        layer.stroke(path,
                     with: .color(accent.opacity(0.38 * neonFlicker)),
                     style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // Mid bloom
        layer.addFilter(.shadow(color: accent.opacity(0.35 * neonFlicker), radius: 12, x: 0, y: 0))
        layer.stroke(path,
                     with: .color(accent.opacity(0.22 * neonFlicker)),
                     style: StrokeStyle(lineWidth: 8, lineCap: .round))

        // Wide mist
        layer.addFilter(.shadow(color: accent.opacity(0.20 * neonFlicker), radius: 18, x: 0, y: 0))
        layer.stroke(path,
                     with: .color(accent.opacity(0.12 * neonFlicker)),
                     style: StrokeStyle(lineWidth: 12, lineCap: .round))
    }
}


// MARK: - Share sheet wrapper
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems,
                                          applicationActivities: applicationActivities)

        if let pop = vc.popoverPresentationController {
            pop.sourceRect = CGRect(x: UIScreen.main.bounds.midX,
                                    y: UIScreen.main.bounds.maxY - 1,
                                    width: 0, height: 0)
            pop.sourceView = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

private extension Double {
    func clamped(to range: ClosedRange<CGFloat>) -> Double {
        Double(Swift.max(range.lowerBound, Swift.min(range.upperBound, CGFloat(self))))
    }
}
