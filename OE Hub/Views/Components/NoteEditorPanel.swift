import SwiftUI
import UIKit

struct NoteEditorPanel: View {
    @Binding var isPresented: Bool

    let title: String
    @Binding var summary: String

    // Edits the caller’s attributed text directly
    @Binding var attributedText: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    let colors: [Color]
    @Binding var colorIndex: Int

    var onCancel: () -> Void
    var onSave: () -> Void

    // Show trash only when editing an existing note
    var onDelete: (() -> Void)? = nil

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    // MARK: - Bullet config
    private let bulletPrefix = "•\t"     // bullet + tab for nice alignment
    private let bulletIndent: CGFloat = 24

    var body: some View {
        ZStack {
            // Dimmed backdrop; tap outside to dismiss
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Floating panel
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Summary
                        Group {
                            Text("Summary")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Short description", text: $summary)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Formatting toolbar
                        HStack(spacing: 10) {
                            formatButton(system: "bold", label: "Bold") { toggleBold() }
                            formatButton(system: "underline", label: "Underline") { toggleUnderline() }
                            formatButton(system: "strikethrough", label: "Strikethrough") { toggleStrikethrough() }
                            formatButton(system: "list.bullet", label: "Bulleted List") { insertBulletedList() }
                            Spacer()
                            colorMenu
                        }

                        // Editor
                        RichTextEditorKit(
                            attributedText: $attributedText,
                            selectedRange: $selectedRange,
                            bulletPrefix: bulletPrefix,
                            bulletIndent: bulletIndent
                        )
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(innerCardBackground(corner: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(16)
                }

                // Footer actions
                HStack(spacing: 12) {
                    Button("Cancel") { onCancel(); dismiss() }
                        .foregroundStyle(.red)

                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(saveEnabled ? Color.green.opacity(0.85) : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!saveEnabled)

                    if onDelete != nil {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Delete Note")
                        .background(Color.red.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: 520)
            .background(panelBackground) // glass bubble
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var saveEnabled: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func dismiss() { isPresented = false }

    // MARK: - Backgrounds

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func innerCardBackground(corner: CGFloat) -> some View {
        if #available(iOS 26.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: corner))
        } else {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
        }
    }

    // MARK: - Toolbar helpers

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

    private var colorMenu: some View {
        Menu {
            ForEach(0..<colors.count, id: \.self) { idx in
                Button { colorIndex = idx } label: {
                    HStack {
                        Circle().fill(colors[idx]).frame(width: 14, height: 14)
                        Text(colorName(for: idx))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(colors[safeIndex(colorIndex)]).frame(width: 16, height: 16)
                Text("Color").font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }

    // MARK: - Formatting actions

    private func toggleBold() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let base = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let hasBold = base.fontDescriptor.symbolicTraits.contains(.traitBold)
            let newDescriptor = base.fontDescriptor.withSymbolicTraits(
                hasBold ? base.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                        : base.fontDescriptor.symbolicTraits.union(.traitBold)
            )
            let newFont = newDescriptor.flatMap { UIFont(descriptor: $0, size: base.pointSize) } ?? base
            m.addAttribute(.font, value: newFont, range: subRange)
        }
        attributedText = m
    }

    private func toggleUnderline() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.underlineStyle, range: subRange) }
            else { m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        attributedText = m
    }

    private func toggleStrikethrough() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.strikethroughStyle, range: subRange) }
            else { m.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        attributedText = m
    }

    /// Turns the current paragraph(s) into bullets with proper paragraph style.
    private func insertBulletedList() {
        let current = attributedText
        let ns = current.string as NSString
        var sel = normalizedSelection()

        // If document is empty: insert a brand new bullet line
        if current.length == 0 {
            let attrs = attributesForInsertion(at: 0, fallbackOnly: true)
            let p = bulletParagraphStyle(basedOn: attrs[.paragraphStyle] as? NSParagraphStyle)
            var merged = attrs
            merged[.paragraphStyle] = p

            let m = NSMutableAttributedString()
            m.append(NSAttributedString(string: bulletPrefix, attributes: merged))
            attributedText = m
            selectedRange = NSRange(location: bulletPrefix.count, length: 0)
            return
        }

        // Expand to whole paragraphs if just a caret
        if sel.length == 0 {
            sel = ns.paragraphRange(for: sel)
        }

        // Walk paragraphs within selection
        var offset = 0
        let m = NSMutableAttributedString(attributedString: current)
        ns.enumerateSubstrings(in: sel, options: [.byParagraphs, .substringNotRequired]) { _, pr, _, _ in
            let insertLoc = pr.location + offset
            // Get actual text to check if already bulleted
            let lineText = ns.substring(with: pr)
            if lineText.hasPrefix(self.bulletPrefix) || lineText.hasPrefix("• ") || lineText.hasPrefix("- ") {
                // Ensure paragraph style is correct (reapply)
                let attrs = self.attributesForInsertion(at: insertLoc, fallbackOnly: true)
                let p = self.bulletParagraphStyle(basedOn: attrs[.paragraphStyle] as? NSParagraphStyle)
                m.addAttribute(.paragraphStyle, value: p, range: NSRange(location: insertLoc, length: pr.length))
                return
            }

            // Insert bullet and tab, and apply paragraph style
            let attrs = self.attributesForInsertion(at: insertLoc, fallbackOnly: true)
            let p = self.bulletParagraphStyle(basedOn: attrs[.paragraphStyle] as? NSParagraphStyle)
            var merged = attrs
            merged[.paragraphStyle] = p

            m.insert(NSAttributedString(string: self.bulletPrefix, attributes: merged), at: insertLoc)
            offset += self.bulletPrefix.count
            // Also apply the paragraph style across the paragraph’s new range
            let styledRange = NSRange(location: insertLoc, length: pr.length + self.bulletPrefix.count)
            m.addAttribute(.paragraphStyle, value: p, range: styledRange)
        }

        attributedText = m
        // If caret was inside first paragraph start, nudge past bullet
        if selectedRange.length == 0 {
            let firstPara = ns.paragraphRange(for: selectedRange)
            if selectedRange.location == firstPara.location {
                selectedRange = NSRange(location: selectedRange.location + bulletPrefix.count, length: 0)
            }
        }
    }

    // MARK: - Paragraph style helpers

    private func bulletParagraphStyle(basedOn base: NSParagraphStyle?) -> NSParagraphStyle {
        let p = (base?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        // Align text after a bullet + tab
        p.firstLineHeadIndent = 0
        p.headIndent = bulletIndent
        p.defaultTabInterval = bulletIndent
        p.tabStops = [NSTextTab(textAlignment: .left, location: bulletIndent, options: [:])]
        return p
    }

    private func normalParagraphStyle(basedOn base: NSParagraphStyle?) -> NSParagraphStyle {
        let p = (base?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        p.firstLineHeadIndent = 0
        p.headIndent = 0
        p.tabStops = []
        p.defaultTabInterval = 0
        return p
    }

    // MARK: - Selection + attributes

    private func attributesForInsertion(at location: Int, fallbackOnly: Bool) -> [NSAttributedString.Key: Any] {
        // Safeguard
        let loc = max(0, min(location, max(attributedText.length - 1, 0)))
        var attrs = attributedText.length > 0 ? attributedText.attributes(at: loc, effectiveRange: nil) : [:]

        let hasFont = attrs[.font] != nil
        let hasColor = attrs[.foregroundColor] != nil

        if fallbackOnly || !hasFont {
            attrs[.font] = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        }
        if fallbackOnly || !hasColor {
            attrs[.foregroundColor] = (attrs[.foregroundColor] as? UIColor) ?? UIColor.label
        }
        return attrs
    }

    private func normalizedSelection() -> NSRange {
        var r = selectedRange
        if r.location == NSNotFound { r = NSRange(location: 0, length: 0) }
        if r.length == 0 {
            let ns = attributedText.string as NSString
            r = ns.paragraphRange(for: r)
        }
        let maxLen = max(0, attributedText.length)
        let loc = min(max(0, r.location), maxLen)
        let len = min(max(0, r.length), maxLen - loc)
        return NSRange(location: loc, length: len)
    }

    // MARK: - Helpers

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
        default: return "Color"
        }
    }

    private func safeIndex(_ idx: Int) -> Int {
        return ((idx % colors.count) + colors.count) % colors.count
    }
}

// MARK: - UITextView-backed rich editor with bullet continuation
struct RichTextEditorKit: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange

    // Bullet configuration injected from the panel
    let bulletPrefix: String
    let bulletIndent: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.allowsEditingTextAttributes = true

        tv.attributedText = attributedText
        tv.selectedRange = selectedRange
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        if uiView.selectedRange.location != selectedRange.location || uiView.selectedRange.length != selectedRange.length {
            uiView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorKit
        init(_ parent: RichTextEditorKit) { self.parent = parent }

        // Continue / end bullet lists on Return
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            guard text == "\n" else { return true }

            let att = textView.attributedText ?? NSAttributedString(string: "")
            let ns = att.string as NSString
            let caret = range.location
            let paraRange = ns.paragraphRange(for: NSRange(location: caret, length: 0))
            let line = ns.substring(with: paraRange)

            let hasBullet = line.hasPrefix(parent.bulletPrefix) || line.hasPrefix("• ") || line.hasPrefix("- ")

            // If not a bullet paragraph → allow default newline
            if !hasBullet { return true }

            // Determine text (minus prefix) to see if it's empty
            let contentAfterPrefix: String = {
                if line.hasPrefix(parent.bulletPrefix) {
                    return String(line.dropFirst(parent.bulletPrefix.count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("• ") {
                    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("- ") {
                    return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                return line.trimmingCharacters(in: .whitespaces)
            }()

            // Prepare mutable copy
            let m = NSMutableAttributedString(attributedString: att)

            // Grab current typing attributes (font/color)
            // In RichTextEditorKit.Coordinator -> shouldChangeTextIn:
            let typingAttrs = textView.typingAttributes   // was: var typingAttrs = ...
            let baseFont = (typingAttrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let baseColor = (typingAttrs[.foregroundColor] as? UIColor) ?? .label

            // Paragraph styles
            let bulletStyle: NSParagraphStyle = {
                let p = (typingAttrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                p.firstLineHeadIndent = 0
                p.headIndent = parent.bulletIndent
                p.defaultTabInterval = parent.bulletIndent
                p.tabStops = [NSTextTab(textAlignment: .left, location: parent.bulletIndent, options: [:])]
                return p
            }()

            let normalStyle: NSParagraphStyle = {
                let p = (typingAttrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                p.firstLineHeadIndent = 0
                p.headIndent = 0
                p.tabStops = []
                p.defaultTabInterval = 0
                return p
            }()

            if contentAfterPrefix.isEmpty {
                // END LIST: Remove the bullet-only paragraph and insert a normal newline
                // 1) Delete entire paragraph (which currently contains only a bullet)
                m.replaceCharacters(in: paraRange, with: NSAttributedString(string: ""))
                // 2) Insert a plain newline at the original paragraph start
                let insertLoc = paraRange.location
                let nl = NSAttributedString(string: "\n", attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .paragraphStyle: normalStyle
                ])
                m.insert(nl, at: insertLoc)

                textView.attributedText = m
                textView.selectedRange = NSRange(location: insertLoc + 1, length: 0)
                // Update SwiftUI bindings
                DispatchQueue.main.async {
                    self.parent.attributedText = textView.attributedText
                    self.parent.selectedRange = textView.selectedRange
                }
                return false
            } else {
                // CONTINUE LIST: Insert newline + fresh bullet with bullet paragraph style
                let insertLoc = range.location
                let continuation = NSMutableAttributedString(string: "\n", attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .paragraphStyle: bulletStyle
                ])
                continuation.append(NSAttributedString(string: self.parent.bulletPrefix, attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .paragraphStyle: bulletStyle
                ]))

                m.replaceCharacters(in: range, with: continuation)

                textView.attributedText = m
                textView.selectedRange = NSRange(location: insertLoc + continuation.length, length: 0)
                // Keep typing attributes consistent for the next characters
                var nextTyping = textView.typingAttributes
                nextTyping[.paragraphStyle] = bulletStyle
                nextTyping[.font] = baseFont
                nextTyping[.foregroundColor] = baseColor
                textView.typingAttributes = nextTyping

                // Update SwiftUI bindings
                DispatchQueue.main.async {
                    self.parent.attributedText = textView.attributedText
                    self.parent.selectedRange = textView.selectedRange
                }
                return false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            let newValue: NSAttributedString = textView.attributedText ?? NSAttributedString(string: "")
            if parent.attributedText != newValue {
                DispatchQueue.main.async {
                    self.parent.attributedText = newValue
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let newRange = textView.selectedRange
            if self.parent.selectedRange.location != newRange.location ||
               self.parent.selectedRange.length   != newRange.length {
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                }
            }
        }
    }
}
