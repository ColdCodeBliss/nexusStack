//
//  GitHubBrowserView.swift
//  nexusStack / OE Hub
//  Floating panel version (Beta Liquid Glass only)
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Models

fileprivate struct RepoRef: Equatable {
    var owner: String
    var name: String
    var branch: String?      // optional override from URL (e.g., .../tree/<branch>/...)
    var initialPath: String? // optional initial subpath from URL
}

fileprivate struct ContentItem: Decodable, Identifiable {
    let name: String
    let path: String
    let sha: String
    let size: Int?
    let type: String           // "file" | "dir" | "symlink" | "submodule"
    let download_url: String?  // only for files
    let html_url: String?      // nice to have
    let encoding: String?
    let content: String?
    var id: String { sha }
}

// MARK: - Service

fileprivate enum GHService {
    static let base = URL(string: "https://api.github.com")!

    static func fetchDefaultBranch(owner: String, repo: String) async throws -> String {
        let url = base.appending(path: "/repos/\(owner)/\(repo)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (obj?["default_branch"] as? String) ?? "main"
    }

    static func listContents(owner: String, repo: String, path: String?, ref: String) async throws -> [ContentItem] {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path ?? "")"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([ContentItem].self, from: data)
    }

    static func fetchFile(owner: String, repo: String, path: String, ref: String) async throws -> ContentItem {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ContentItem.self, from: data)
    }

    static func fetchRaw(url: URL) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - Main Browser View (per-job recents)

struct GitHubBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    /// Per-job UserDefaults key (namespaced by Job.repoBucketKey via caller)
    let recentKey: String
    /// Max recent repos to keep
    let maxRecents: Int = 3

    // MARK: Persistence via @AppStorage (dynamic key)
    @AppStorage private var recentReposJSON: String

    // Appearance flags (Beta Liquid Glass only)
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.60

    // Input
    @State private var repoURLString: String = ""
    // Parsed
    @State private var repo: RepoRef? = nil
    @State private var branch: String = "main"
    @State private var currentPath: String = ""

    // Data
    @State private var items: [ContentItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // File preview
    @State private var showingFile: Bool = false
    @State private var fileTitle: String = ""
    @State private var fileText: String = ""
    @State private var fileData: Data? = nil
    @State private var fileIsText: Bool = true
    @State private var fileDownloadURL: URL? = nil

    // Per-job recents (in-memory working copy)
    @State private var recentRepos: [String] = []

    // Bind @AppStorage to dynamic key
    init(recentKey: String) {
        self.recentKey = recentKey
        self._recentReposJSON = AppStorage(wrappedValue: "[]", recentKey)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset    = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let dim         = (isBetaGlassEnabled ? 0.14 : 0.25)

            ZStack {
                // Backdrop dim
                Color.black.opacity(dim).ignoresSafeArea()

                // Floating glass panel
                panel
                    .frame(maxWidth: hSize == .regular ? 520 : .infinity)
                    .background(panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
                    .padding(.horizontal, 16)
                    .modifier(BetaGlow(opacity: betaWhiteGlowOpacity))
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top,    max(topInset, 12))
                    .padding(.bottom, max(bottomInset, 12))
                    .modifier(
                        MaxHeightIfPositive(
                            maxHeight: max(0, proxy.size.height - max(topInset, 12) - max(bottomInset, 12))
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .presentationBackground(.clear)
        .onAppear(perform: loadRecents)
        .sheet(isPresented: $showingFile) { filePreview }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView { content }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }
                .font(.callout.weight(.semibold))

            Spacer()

            Text(repoTitle)
                .font(.headline)

            Spacer()

            if repo != nil {
                Button {
                    Task { await reloadCurrentFolder() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .padding(12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            // URL entry + Recents
            urlEntryCard

            // Error
            if let err = errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }

            // Directory listing
            if repo != nil {
                directoryCard
            }
        }
        .padding(16)
        .onDrop(of: [.url, .text], isTargeted: nil, perform: handleDrop(_:))
    }

    // MARK: - Cards

    private var urlEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load a public GitHub repository")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("e.g. https://github.com/apple/swift", text: $repoURLString)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.URL)
                .padding(10)
                .background(cardRowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))

            loadButton

            if !recentRepos.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("Recent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    CenteredWrap(spacing: 8) {
                        ForEach(recentRepos, id: \.self) { url in
                            Button {
                                repoURLString = url
                                Task { await loadFromURL() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text(shortLabel(for: url))
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(chipBackground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }

    private var directoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Path header
            if !currentPath.isEmpty {
                Button {
                    goUpOne()
                } label: {
                    Label("..", systemImage: "arrow.up.left")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(cardRowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08)))
            }

            // Items
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: iconName(for: item))
                                .foregroundStyle(item.type == "dir" ? .yellow : .secondary)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.body)
                                Text(item.path).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await handleTap(item) } }
                        .padding(10)
                        .background(cardRowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08)))
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }

    // MARK: - Buttons

    private var loadButton: some View {
        Group {
            if #available(iOS 26.0, *), isBetaGlassEnabled {
                Button("Load Repository") { Task { await loadFromURL() } }
                    .buttonStyle(.glass)
                    .disabled(repoURLString.isEmpty)
            } else {
                Button("Load Repository") { Task { await loadFromURL() } }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.85)))
                    .foregroundStyle(.white)
                    .disabled(repoURLString.isEmpty)
            }
        }
    }

    // MARK: - Backgrounds (Beta or fallback only)

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    private var cardRowBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.white.opacity(0.06)
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground))
        }
    }

    @ViewBuilder
    private var chipBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.white.opacity(0.08)
        } else {
            Color.gray.opacity(0.15)
        }
    }

    private struct BetaGlow: ViewModifier {
        @Environment(\.colorScheme) private var scheme
        let opacity: Double
        func body(content: Content) -> some View {
            content.shadow(color: scheme == .dark ? .white.opacity(opacity) : .clear,
                           radius: 10, x: 0, y: 0)
        }
    }

    // MARK: - Actions

    private var repoTitle: String {
        if let r = repo { return "\(r.owner)/\(r.name)" }
        return "GitHub"
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if let item = providers.first {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task {
                        await MainActor.run {
                            repoURLString = url.absoluteString
                            Task { await loadFromURL() }
                        }
                    }
                }
            }
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let d = data as? Data, let s = String(data: d, encoding: .utf8) {
                    Task { await MainActor.run {
                        repoURLString = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await loadFromURL() }
                    } }
                }
            }
        }
        return true
    }

    private func loadFromURL() async {
        errorMessage = nil
        guard let parsed = parseRepoURL(repoURLString) else {
            errorMessage = "Unable to parse owner/repo from URL."
            return
        }
        repo = parsed
        isLoading = true
        do {
            let defaultBranch = try await GHService.fetchDefaultBranch(owner: parsed.owner, repo: parsed.name)
            branch = parsed.branch ?? defaultBranch
            currentPath = parsed.initialPath ?? ""
            items = try await GHService.listContents(owner: parsed.owner, repo: parsed.name, path: currentPath.isEmpty ? nil : currentPath, ref: branch)

            // Save to per-job recents
            pushRecent(url: repoURLString)
        } catch {
            errorMessage = "Failed to load repository. Please check the URL and try again."
            repo = nil
        }
        isLoading = false
    }

    private func reloadCurrentFolder() async {
        guard let r = repo else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await GHService.listContents(owner: r.owner, repo: r.name, path: currentPath.isEmpty ? nil : currentPath, ref: branch)
        } catch {
            errorMessage = "Failed to reload folder."
        }
    }

    private func handleTap(_ item: ContentItem) async {
        guard let r = repo else { return }
        if item.type == "dir" {
            currentPath = item.path
            await reloadCurrentFolder()
            return
        }

        // File tap
        isLoading = true
        defer { isLoading = false }
        do {
            // Fetch full content via the API to get base64 for text files
            let file = try await GHService.fetchFile(owner: r.owner, repo: r.name, path: item.path, ref: branch)
            fileTitle = item.name
            fileDownloadURL = file.download_url.flatMap(URL.init(string:))

            // Try text via base64
            if let enc = file.encoding?.lowercased(), enc == "base64", let b64 = file.content,
               let data = Data(base64Encoded: b64),
               let text = String(data: data, encoding: .utf8) {
                fileText = text
                fileData = nil
                fileIsText = true
                showingFile = true
                return
            }

            // Not text (or failed to decode) → raw
            if let rawURL = fileDownloadURL {
                let data = try await GHService.fetchRaw(url: rawURL)
                fileData = data
                fileIsText = isProbablyText(data) == true ? true : false
                if fileIsText, let text = String(data: data, encoding: .utf8) {
                    fileText = text
                    fileData = nil
                }
                showingFile = true
            } else {
                fileText = "(Unable to display file. Try 'Open Raw'.)"
                fileData = nil
                fileIsText = true
                showingFile = true
            }
        } catch {
            fileTitle = item.name
            fileText = "Failed to load file."
            fileData = nil
            fileIsText = true
            showingFile = true
        }
    }

    private func goUpOne() {
        guard !currentPath.isEmpty else { return }
        var comps = currentPath.split(separator: "/").map(String.init)
        _ = comps.popLast()
        currentPath = comps.joined(separator: "/")
        Task { await reloadCurrentFolder() }
    }

    // MARK: - Per-job recents (@AppStorage JSON)

    private func loadRecents() {
        recentRepos = decodeRecent(recentReposJSON)
    }

    private func pushRecent(url: String) {
        var arr = decodeRecent(recentReposJSON)
        // Remove duplicates (move to front, case-insensitive)
        arr.removeAll { $0.caseInsensitiveCompare(url) == .orderedSame }
        arr.insert(url, at: 0)
        // Cap
        if arr.count > maxRecents { arr = Array(arr.prefix(maxRecents)) }
        recentRepos = arr
        recentReposJSON = encodeRecent(arr)
    }

    private func decodeRecent(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    private func encodeRecent(_ arr: [String]) -> String {
        (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    // MARK: - Parsing / helpers

    /// Accepts: https://github.com/<owner>/<repo>
    /// Also accepts: https://github.com/<owner>/<repo>/tree/<branch>/<optional/path...>
    private func parseRepoURL(_ str: String) -> RepoRef? {
        guard let url = URL(string: str), url.host?.lowercased().contains("github.com") == true else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let owner = parts[0]
        let name  = parts[1]

        if parts.count >= 4, parts[2] == "tree" {
            let branch = parts[3]
            let extraPath = parts.dropFirst(4).joined(separator: "/")
            return RepoRef(owner: owner, name: name, branch: branch, initialPath: extraPath.isEmpty ? nil : extraPath)
        }
        return RepoRef(owner: owner, name: name, branch: nil, initialPath: nil)
    }

    private func shortLabel(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let comps = url.path.split(separator: "/").map(String.init)
        if comps.count >= 2 { return "\(comps[0])/\(comps[1])" }
        return urlString.replacingOccurrences(of: "https://", with: "")
    }

    private func iconName(for item: ContentItem) -> String {
        if item.type == "dir" { return "folder" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return "doc.text"
        case "json", "yml", "yaml", "xml", "plist": return "curlybraces.square"
        case "swift", "m", "mm", "h", "cpp", "c", "js", "ts", "java", "kt", "py", "rb", "go", "rs", "php":
            return "chevron.left.slash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "heic": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    private func isProbablyText(_ data: Data) -> Bool {
        if let _ = String(data: data, encoding: .utf8) { return true }
        return false
    }

    // MARK: - File Preview

    @ViewBuilder
    private var filePreview: some View {
        NavigationStack {
            Group {
                if fileIsText {
                    ScrollView {
                        Text(fileText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else if let data = fileData,
                          let image = UIImage(data: data),
                          let cgImage = image.cgImage {
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .background(Color.black.opacity(0.05))
                } else if let _ = fileData {
                    VStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Preview not supported")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Preview not supported")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle(fileTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { showingFile = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = fileDownloadURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    } else if fileIsText {
                        ShareLink(item: fileText) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }
}

// MARK: - Centered, wrapping layout for chips (iOS 16+)

fileprivate struct CenteredWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        guard maxWidth > 0 else {
            let totalHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.reduce(0, +)
                + spacing * max(0, CGFloat(subviews.count - 1))
            let maxW = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
            return CGSize(width: maxW, height: totalHeight)
        }

        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var hasAny = false

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let next = (currentRowWidth == 0 ? size.width : currentRowWidth + spacing + size.width)
            if next > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                hasAny = true
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = next
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        if currentRowWidth > 0 { totalHeight += currentRowHeight; hasAny = true }
        if !hasAny { totalHeight = 0 }
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        guard maxWidth > 0 else { return }

        // Build rows
        var rows: [[(Int, CGSize)]] = []
        var row: [(Int, CGSize)] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let next = (rowWidth == 0 ? size.width : rowWidth + spacing + size.width)
            if next > maxWidth, !row.isEmpty {
                rows.append(row)
                row = [(i, size)]
                rowWidth = size.width
                rowHeight = size.height
            } else {
                row.append((i, size))
                rowWidth = next
                rowHeight = max(rowHeight, size.height)
            }
        }
        if !row.isEmpty { rows.append(row) }

        // Center each row
        var y = bounds.minY
        for r in rows {
            let rWidth = r.reduce(0) { partial, pair in partial == 0 ? pair.1.width : partial + spacing + pair.1.width }
            let rHeight = r.map { $0.1.height }.max() ?? 0
            var x = bounds.minX + (maxWidth - rWidth) / 2

            for (idx, size) in r {
                subviews[idx].place(
                    at: CGPoint(x: x, y: y + (rHeight - size.height)/2),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += rHeight + spacing
        }
    }
}

// MARK: - Safe height clamp

private struct MaxHeightIfPositive: ViewModifier {
    let maxHeight: CGFloat
    func body(content: Content) -> some View {
        if maxHeight > 0, maxHeight.isFinite {
            content.frame(maxHeight: maxHeight)
        } else {
            content
        }
    }
}
