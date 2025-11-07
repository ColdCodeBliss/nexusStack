//
//  ConfluenceLinksView.swift
//  nexusStack / OE Hub
//  Floating panel version matching SettingsPanel’s Liquid Glass
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfluenceLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.openURL) private var openURL

    // Per-job storage key (e.g., "confluenceLinks.<job.repoBucketKey>")
    let storageKey: String
    // Max links to keep
    let maxLinks: Int

    // Persisted JSON array of strings under `storageKey`
    @AppStorage private var linksJSON: String

    // Style flags (mirror SettingsPanel / JobDetailView)
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false   // Real glass (iOS 26+)
    @AppStorage("betaWhiteGlowOpacity") private var betaWhiteGlowOpacity: Double = 0.60

    // Working state
    @State private var links: [String] = []
    @State private var inputURL: String = ""
    @State private var errorMessage: String?
    @State private var isEditing: Bool = false

    init(storageKey: String, maxLinks: Int = 5) {
        self.storageKey = storageKey
        self.maxLinks = maxLinks
        self._linksJSON = AppStorage(wrappedValue: "[]", storageKey)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset    = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom
            let dim = (isBetaGlassEnabled ? 0.14 : 0.25) // lighter dim in Beta

            ZStack {
                // Fullscreen dim background
                Color.black.opacity(dim)
                    .ignoresSafeArea()

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
                    // Respect safe areas so header is below the status bar and corners don't clip
                    .padding(.top,    max(topInset, 12))
                    .padding(.bottom, max(bottomInset, 12))
                    // Cap height safely (avoid negative/non-finite on first layout pass)
                    .modifier(
                        MaxHeightIfPositive(
                            maxHeight: max(0, proxy.size.height - max(topInset, 12) - max(bottomInset, 12))
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Keep the system sheet behind transparent
        .presentationBackground(.clear)
        .onAppear(perform: load)
    }

    // MARK: - Panel pieces

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView { content }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(isEditing ? "Done" : "Edit") { withAnimation { isEditing.toggle() } }
                .font(.callout.weight(.semibold))

            Spacer()

            Text("Confluence")
                .font(.headline)

            Spacer()

            Button("Done") { dismiss() }
                .font(.callout.weight(.semibold))
        }
        .padding(12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            addLinkCard
            if let err = errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
            savedLinksCard
        }
        .padding(16)
        .onDrop(of: [.url, .text], isTargeted: nil, perform: handleDrop(_:))
    }

    // MARK: - Cards

    private var addLinkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Confluence Link")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            linkInputField
            addButton
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }

    private var savedLinksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved Links")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if links.isEmpty {
                Text("No saved Confluence links yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(cardRowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(links, id: \.self) { url in
                        linkRow(url)
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
    }

    // MARK: - Row + Input

    private func linkRow(_ url: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortLabel(for: url))
                    .font(.body)
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if isEditing {
                Button {
                    deleteLink(url)
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { open(urlString: url) } }
        .contextMenu {
            Button("Copy") { UIPasteboard.general.string = url }
            Button("Open") { open(urlString: url) }
            Button("Delete", role: .destructive) { deleteLink(url) }
        }
        .padding(10)
        .background(cardRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08)))
    }

    private var linkInputField: some View {
        TextField("https://your-space.atlassian.net/wiki/...", text: $inputURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled(true)
            .submitLabel(.go)
            .onSubmit { addLink() }
            .textFieldStyle(.plain)
            .padding(10)
            .background(cardRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))
    }

    private var addButton: some View {
        Group {
            if #available(iOS 26.0, *), isBetaGlassEnabled {
                Button("Add Link") { addLink() }
                    .buttonStyle(.glass)
                    .disabled(!isValidURL(normalized(inputURL)))
            } else {
                Button("Add Link") { addLink() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.85))
                    )
                    .foregroundStyle(.white)
                    .disabled(!isValidURL(normalized(inputURL)))
            }
        }
    }

    // MARK: - Backgrounds (aligned with SettingsPanel)

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
            Color.white.opacity(0.06) // faint lift over glass
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground))
        }
    }

    private struct BetaGlow: ViewModifier {
        @Environment(\.colorScheme) private var scheme
        let opacity: Double
        func body(content: Content) -> some View {
            content.shadow(
                color: scheme == .dark ? .white.opacity(opacity) : .clear,
                radius: 10, x: 0, y: 0
            )
        }
    }

    // MARK: - Actions

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if let item = providers.first {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { await MainActor.run { inputURL = url.absoluteString; addLink() } }
                }
            }
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let d = data as? Data, let s = String(data: d, encoding: .utf8) {
                    Task { await MainActor.run {
                        inputURL = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        addLink()
                    } }
                }
            }
        }
        return true
    }

    private func addLink() {
        errorMessage = nil
        let urlString = normalized(inputURL)

        guard isValidURL(urlString) else {
            errorMessage = "Please enter a valid URL (http/https)."
            return
        }

        // De-dupe (case-insensitive) & cap
        var arr = links
        arr.removeAll { $0.caseInsensitiveCompare(urlString) == .orderedSame }
        arr.insert(urlString, at: 0)
        if arr.count > maxLinks { arr = Array(arr.prefix(maxLinks)) }

        links = arr
        save()
        inputURL = ""
    }

    private func deleteLink(_ url: String) {
        links.removeAll { $0 == url }
        save()
    }

    private func normalized(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        return s
    }

    private func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url) // Universal Links
    }

    // MARK: - Persistence

    private func load() { links = decode(linksJSON) }
    private func save() { linksJSON = encode(links) }

    private func decode(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    private func encode(_ arr: [String]) -> String {
        (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    // MARK: - Helpers

    private func isValidURL(_ str: String) -> Bool {
        guard let url = URL(string: str),
              let scheme = url.scheme?.lowercased(),
              url.host != nil else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func shortLabel(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let host = url.host ?? ""
        let tail = url.path.split(separator: "/").last.map(String.init) ?? ""
        return tail.isEmpty ? host : "\(host) • \(tail)"
    }
}

// MARK: - Safe height clamp (prevents “Invalid frame dimension”)

private struct MaxHeightIfPositive: ViewModifier {
    let maxHeight: CGFloat
    func body(content: Content) -> some View {
        if maxHeight > 0, maxHeight.isFinite {
            content.frame(maxHeight: maxHeight)
        } else {
            content // leave unconstrained until we have a valid size
        }
    }
}
