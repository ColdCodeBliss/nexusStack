import SwiftUI
import SwiftData
import UIKit

struct NotesTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var theme: ThemeManager

    // Editor state
    @State private var isAddingNote = false
    @State private var isEditingNote = false
    @State private var newNoteContent = ""
    @State private var newNoteSummary = ""
    @State private var selectedNote: Note? = nil

    // Rich text buffer (non-Beta sheet + Beta panel)
    @State private var editingAttributed: NSAttributedString = NSAttributedString(string: "")
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)

    // Color picker state
    @State private var editingColorIndex: Int = 0

    // Style toggles
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    // Parent-driven trigger for the nav-bar “+”
    @Binding var addNoteTrigger: Int

    var job: Job

    // MARK: - Precomputed constants
    private let colors: [Color] = [.red, .blue, .green, .orange, .yellow, .purple, .brown, .teal, .black, .white]
    private let gridColumns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    // Bullet configuration (shared with Beta panel)
    private let bulletPrefix: String = "•\t"
    private let bulletIndent: CGFloat = 24

    // Adds headroom beneath the inline toolbar title in the sheet
    private let navBuffer: CGFloat = 50

    private var sortedNotes: [Note] {
        job.notes.sorted { $0.creationDate > $1.creationDate }
    }

    private var nextColorIndex: Int {
        let used = Set(job.notes.map { $0.colorIndex })
        for i in 0..<colors.count where !used.contains(i) { return i }
        return job.notes.count % colors.count
    }

    // 🌙 Midnight Neon — shared, subtle flicker for tiles in this view
    @State private var neonFlicker: Double = 1.0
    @State private var flickerArmed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row: "Notes" + glassy "+"
            HStack(spacing: 8) {
                Text("Notes")
                    .font(.headline)

                Spacer()

                Button {
                    // Opens the same compose flow you already use
                    prepareNewNote()
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
                .accessibilityLabel("Add Note")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Grid of notes
            ScrollView {
                makeGrid(notes: sortedNotes)
                    .padding()
            }
        }
        // Keep your existing editors exactly as-is
        .sheet(isPresented: nonBetaSheetIsPresented) { nonBetaSheet }
        .overlay { betaOverlay }
        .navigationTitle("Notes") // harmless; hidden by inline header if shown in a sheet
        .animation(.default, value: job.notes.count)
        .onChange(of: addNoteTrigger) { _, _ in prepareNewNote() }
        // Neon flicker lifecycle
        .onAppear { armFlickerIfNeeded() }
        .onDisappear { flickerArmed = false }
        .onChange(of: theme.currentID) { _, _ in armFlickerIfNeeded() }
    }

    // MARK: - Builders

    @ViewBuilder
    private func makeGrid(notes: [Note]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(notes) { note in
                noteTile(for: note)
                    .onTapGesture { openEditor(for: note) }
            }
        }
    }

    private var nonBetaSheetIsPresented: Binding<Bool> {
        Binding(
            get: { (isAddingNote || isEditingNote) && !isBetaGlassEnabled },
            set: { if !$0 { dismissEditor() } }
        )
    }

    // MARK: - Non-Beta rich-text sheet editor (small inline title + Done + top inset)
    @ViewBuilder
    private var nonBetaSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Summary
                TextField("Summary (short description)", text: $newNoteSummary)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                // Formatting toolbar
                HStack(spacing: 10) {
                    formatButton(system: "bold", label: "Bold") { nb_toggleBold() }
                    formatButton(system: "underline", label: "Underline") { nb_toggleUnderline() }
                    formatButton(system: "strikethrough", label: "Strikethrough") { nb_toggleStrikethrough() }
                    formatButton(system: "list.bullet", label: "Bulleted List") { nb_insertBulletedList() }
                    Spacer()
                }
                .padding(.horizontal)

                // Rich text editor (UIKit-backed)
                RichTextEditorKit(
                    attributedText: $editingAttributed,
                    selectedRange: $selectionRange,
                    bulletPrefix: bulletPrefix,
                    bulletIndent: bulletIndent
                )
                .frame(minHeight: 220)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Color
                Picker("Color", selection: $editingColorIndex) {
                    ForEach(0..<colors.count, id: \.self) { index in
                        Text(colorName(for: index)).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                // Actions: Cancel | Save | (Trash when editing)
                HStack(spacing: 12) {
                    Button("Cancel") { dismissEditor() }
                        .foregroundStyle(.red)

                    Button("Save") {
                        saveNote(attributed: editingAttributed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(
                        newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        editingAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if selectedNote != nil {
                        Button {
                            deleteCurrentNote()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 48, height: 44)
                        }
                        .background(Color.red.opacity(0.90))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Delete Note")
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            // Small inline title to the left; Done to the right
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(selectedNote != nil ? "Edit Note" : "New Note")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismissEditor() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Reserve headroom below toolbar so subject line never hides behind it
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: navBuffer)
            }
            // Nice keyboard behavior
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Beta overlay
    @ViewBuilder
    private var betaOverlay: some View {
        if (isAddingNote || isEditingNote) && isBetaGlassEnabled {
            NoteEditorPanel(
                isPresented: Binding(
                    get: { isAddingNote || isEditingNote },
                    set: { if !$0 { dismissEditor() } }
                ),
                title: (selectedNote != nil ? "Edit Note" : "New Note"),
                summary: $newNoteSummary,
                attributedText: $editingAttributed,
                colors: colors,
                colorIndex: $editingColorIndex,
                onCancel: { dismissEditor() },
                onSave: { saveNote(attributed: editingAttributed) },
                onDelete: (selectedNote == nil ? nil : {
                    guard let note = selectedNote else { return }
                    if let idx = job.notes.firstIndex(of: note) {
                        job.notes.remove(at: idx)
                    }
                    modelContext.delete(note)
                    try? modelContext.save()
                    dismissEditor()
                })
            )
            .zIndex(2)
        } else {
            EmptyView()
        }
    }

    // MARK: - Tiles

    private func noteTile(for note: Note) -> some View {
        let idx = safeIndex(note.colorIndex)
        let tint = colors[idx]
        let fg: Color = .black
        let isGlass = isBetaGlassEnabled
        let radius: CGFloat = 16
        let neonOn = (theme.currentID == .midnightNeon)

        return VStack(alignment: .leading, spacing: 8) {
            Text(note.summary)
                .font(.headline)
                .foregroundStyle(fg)
            Text(note.creationDate, style: .date)
                .font(.caption)
                .foregroundStyle(fg.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(tileBackground(tint: tint, radius: radius))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
        )

        // 🌙 Midnight Neon tube + glow (contained; no trailing)
        .overlay(neonOverlayTile(radius: radius))

        // Keep legacy shadow unless neon is active (neon handles glow)
        .shadow(
            color: neonOn ? .clear
                          : (isGlass ? .black.opacity(0.25) : .black.opacity(0.15)),
            radius: neonOn ? 0 : (isGlass ? 14 : 5),
            x: 0, y: neonOn ? 0 : (isGlass ? 8 : 0)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func tileBackground(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.55)), in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            // Standard (non-Beta): solid tint gradient
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint.gradient)
        }
    }

    // 🌙 Midnight Neon overlay for a single tile (tube + inner glows, masked)
    @ViewBuilder
    private func neonOverlayTile(radius: CGFloat) -> some View {
        if theme.currentID == .midnightNeon {
            let p = theme.palette(colorScheme)
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            // Tuned alphas for tiles
            let borderAlpha    = isBetaGlassEnabled ? 0.24 : 0.32
            let tubeAlpha      = isBetaGlassEnabled ? 0.55 : 0.65
            let innerGlowAlpha = isBetaGlassEnabled ? 0.22 : 0.28
            let bloomAlpha     = isBetaGlassEnabled ? 0.14 : 0.20

            Group {
                // crisp inset border
                shape
                    .strokeBorder(p.neonAccent.opacity(borderAlpha * neonFlicker), lineWidth: 1)

                // tube core (thin bright line)
                shape
                    .stroke(p.neonAccent.opacity(tubeAlpha * neonFlicker), lineWidth: 2)
                    .blendMode(.plusLighter)
                    .mask(shape.stroke(lineWidth: 2))

                // tight inner glow
                shape
                    .stroke(p.neonAccent.opacity(innerGlowAlpha * neonFlicker), lineWidth: 8)
                    .blur(radius: 9)
                    .blendMode(.plusLighter)
                    .mask(shape.stroke(lineWidth: 10))

                // inner bloom
                shape
                    .stroke(p.neonAccent.opacity(bloomAlpha * neonFlicker), lineWidth: 14)
                    .blur(radius: 16)
                    .blendMode(.plusLighter)
                    .mask(shape.stroke(lineWidth: 16))
            }
        }
    }

    // MARK: - Actions & Helpers

    private func openEditor(for note: Note) {
        selectedNote = note
        newNoteContent = note.content
        newNoteSummary = note.summary
        editingColorIndex = safeIndex(note.colorIndex)
        editingAttributed = note.attributed
        isEditingNote = true
    }

    private func prepareNewNote() {
        selectedNote = nil
        newNoteContent = ""
        newNoteSummary = ""
        editingColorIndex = nextColorIndex
        editingAttributed = NSAttributedString(string: "")
        isAddingNote = true
    }

    private func saveNote(attributed: NSAttributedString?) {
        let trimmedSummary = newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainBody = (attributed?.string ?? newNoteContent).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty, !plainBody.isEmpty else { return }

        if let note = selectedNote {
            note.summary = trimmedSummary
            note.colorIndex = safeIndex(editingColorIndex)
            if let rich = attributed { note.attributed = rich } else { note.content = plainBody }
        } else {
            let idx = safeIndex(editingColorIndex)
            let new = Note(content: plainBody, summary: trimmedSummary, colorIndex: idx)
            if let rich = attributed { new.attributed = rich }
            job.notes.append(new)
        }

        try? modelContext.save()
        dismissEditor()
    }

    private func deleteCurrentNote() {
        guard let note = selectedNote else { return }
        if let idx = job.notes.firstIndex(of: note) {
            let removed = job.notes.remove(at: idx)
            modelContext.delete(removed)
        } else {
            modelContext.delete(note)
        }
        try? modelContext.save()
        dismissEditor()
    }

    private func dismissEditor() {
        isAddingNote = false
        isEditingNote = false
        newNoteContent = ""
        newNoteSummary = ""
        selectedNote = nil
        selectionRange = NSRange(location: 0, length: 0)
        editingAttributed = NSAttributedString(string: "")
    }

    // MARK: - Formatting helpers (non-Beta)

    private func formatButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func nb_normalizedSelection() -> NSRange {
        var r = selectionRange
        if r.location == NSNotFound { r = NSRange(location: 0, length: 0) }
        if r.length == 0 {
            let ns = editingAttributed.string as NSString
            r = ns.paragraphRange(for: r)
        }
        let maxLen = max(0, editingAttributed.length)
        let loc = min(max(0, r.location), maxLen)
        let len = min(max(0, r.length), maxLen - loc)
        return NSRange(location: loc, length: len)
    }

    private func nb_toggleBold() {
        guard editingAttributed.length > 0 else { return }
        let range = nb_normalizedSelection()
        let m = NSMutableAttributedString(attributedString: editingAttributed)
        m.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let base = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let traits = base.fontDescriptor.symbolicTraits
            let hasBold = traits.contains(.traitBold)
            let newDesc = base.fontDescriptor.withSymbolicTraits(hasBold ? traits.subtracting(.traitBold) : traits.union(.traitBold))
            let newFont = newDesc.flatMap { UIFont(descriptor: $0, size: base.pointSize) } ?? base
            m.addAttribute(.font, value: newFont, range: subRange)
        }
        editingAttributed = m
    }

    private func nb_toggleUnderline() {
        guard editingAttributed.length > 0 else { return }
        let range = nb_normalizedSelection()
        let m = NSMutableAttributedString(attributedString: editingAttributed)
        m.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.underlineStyle, range: subRange) }
            else { m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        editingAttributed = m
    }

    private func nb_toggleStrikethrough() {
        guard editingAttributed.length > 0 else { return }
        let range = nb_normalizedSelection()
        let m = NSMutableAttributedString(attributedString: editingAttributed)
        m.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.strikethroughStyle, range: subRange) }
            else { m.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        editingAttributed = m
    }

    private func nb_insertBulletedList() {
        let ns = editingAttributed.string as NSString
        let pr = ns.paragraphRange(for: nb_normalizedSelection())
        let m = NSMutableAttributedString(attributedString: editingAttributed)

        var cursor = pr.location
        while cursor < pr.location + pr.length {
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let attrs = m.attributes(at: lineRange.location, effectiveRange: nil)
            let lineText = (m.string as NSString).substring(with: lineRange)
            let already = lineText.hasPrefix(bulletPrefix)

            if !already {
                let bullet = NSMutableAttributedString(string: bulletPrefix, attributes: attrs)
                let ps = (attrs[.paragraphStyle] as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                ps.tabStops = [NSTextTab(textAlignment: .left, location: bulletIndent)]
                ps.defaultTabInterval = bulletIndent
                ps.headIndent = bulletIndent
                ps.firstLineHeadIndent = 0
                bullet.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: bullet.length))
                m.insert(bullet, at: lineRange.location)
                cursor = lineRange.location + bullet.length + lineRange.length
            } else {
                cursor = lineRange.location + lineRange.length
            }
        }
        editingAttributed = m
    }

    // MARK: - Misc helpers

    private func colorName(for index: Int) -> String {
        switch safeIndex(index) {
        case 0: return "Red"
        case 1: return "Blue"
        case 2: return "Green"
        case 3: return "Orange"
        case 4: return "Yellow"
        case 5: return "Purple"
        case 6: return "Brown"
        case 7: return "Teal"
        case 8: return "Black"
        case 9: return "White"
        default: return "Green"
        }
    }

    private func safeIndex(_ idx: Int) -> Int {
        guard !colors.isEmpty else { return 0 }
        return ((idx % colors.count) + colors.count) % colors.count
    }

    // MARK: - Flicker scheduler

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
