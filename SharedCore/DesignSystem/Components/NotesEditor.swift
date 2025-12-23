import SwiftUI

public struct NotesEditor: View {
    private let title: String
    @Binding private var text: String
    private let placeholder: String
    private let minHeight: CGFloat
    @State private var isFocused: Bool = false

    public init(
        title: String = "Notes",
        text: Binding<String>,
        placeholder: String = "Add notes…",
        minHeight: CGFloat = 120
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if NotesRichTextStorage.plainText(from: text).isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                        .transition(DesignSystem.Transitions.placeholder)
                }

                NotesTextView(text: $text, isFocused: $isFocused)
                    .frame(minHeight: minHeight)
                    .accessibilityLabel("Notes")
                    .accessibilityHint("Editable text. Supports bold and italic formatting.")
            }
            .textFieldStyle(FocusAnimatedTextFieldStyle(isFocused: isFocused))
        }
    }
}

#if os(macOS)
private struct NotesTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textStorage?.setAttributedString(
            NotesRichTextStorage.attributedString(from: text)
        )

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let currentEncoded = NotesRichTextStorage.encode(textView.attributedString())
        if currentEncoded != text {
            textView.textStorage?.setAttributedString(
                NotesRichTextStorage.attributedString(from: text)
            )
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textDidBeginEditing(_ notification: Notification) {
            isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isFocused = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = NotesRichTextStorage.encode(textView.attributedString())
        }
    }
}
#else
private struct NotesTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = RichTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.attributedText = NotesRichTextStorage.attributedString(from: text)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let currentEncoded = NotesRichTextStorage.encode(uiView.attributedText ?? NSAttributedString(string: ""))
        if currentEncoded != text {
            uiView.attributedText = NotesRichTextStorage.attributedString(from: text)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            text = NotesRichTextStorage.encode(textView.attributedText ?? NSAttributedString(string: ""))
        }
    }

    private final class RichTextView: UITextView {
        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(toggleBoldface)),
                UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(toggleItalics))
            ]
        }

        @objc private func toggleBoldface() {
            toggleTrait(.traitBold)
        }

        @objc private func toggleItalics() {
            toggleTrait(.traitItalic)
        }

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let currentFont = typingAttributes[.font] as? UIFont ?? font else { return }
            let range = selectedRange
            let targetTraits: UIFontDescriptor.SymbolicTraits = currentFont.fontDescriptor.symbolicTraits.contains(trait)
                ? currentFont.fontDescriptor.symbolicTraits.subtracting(trait)
                : currentFont.fontDescriptor.symbolicTraits.union(trait)
            let descriptor = currentFont.fontDescriptor.withSymbolicTraits(targetTraits) ?? currentFont.fontDescriptor
            let updatedFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)

            if range.length == 0 {
                typingAttributes[.font] = updatedFont
            } else {
                let mutable = NSMutableAttributedString(attributedString: attributedText)
                mutable.addAttribute(.font, value: updatedFont, range: range)
                attributedText = mutable
                selectedRange = range
            }
        }
    }
}
#endif
