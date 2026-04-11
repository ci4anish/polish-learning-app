import SwiftUI
import UIKit

private extension NSString {
    func wordRange(for range: NSRange) -> NSRange {
        let start = rangeOfWord(at: range.location).location
        let endIndex = range.location + range.length
        let endWord = rangeOfWord(at: max(endIndex - 1, start))
        let end = endWord.location + endWord.length
        return NSRange(location: start, length: end - start)
    }

    private func rangeOfWord(at index: Int) -> NSRange {
        let clamped = max(0, min(index, length - 1))
        var start = clamped
        var end = clamped

        while start > 0 && isWordChar(at: start - 1) { start -= 1 }
        while end < length && isWordChar(at: end) { end += 1 }

        return NSRange(location: start, length: max(end - start, 1))
    }

    private func isWordChar(at index: Int) -> Bool {
        let c = character(at: index)
        guard let scalar = Unicode.Scalar(c) else { return false }
        return CharacterSet.letters.contains(scalar) || CharacterSet(charactersIn: "-'").contains(scalar)
    }
}

struct TextSelection: Equatable {
    let text: String
    let range: NSRange
    let rect: CGRect
}

/// UITextView subclass that suppresses the default edit menu (Copy/Paste/Select All)
/// so only the custom AI magic button appears on selection.
private class MenuFreeTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        nil
    }
}

struct SelectableTextView: UIViewRepresentable {
    let blocks: [TextBlock]
    let onSelectionChange: (TextSelection?) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = MenuFreeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 80, right: 16)
        textView.showsVerticalScrollIndicator = false
        textView.delegate = context.coordinator
        textView.attributedText = Self.buildAttributedString(from: blocks)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func buildAttributedString(from blocks: [TextBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = YapsTheme.textViewLineSpacing
        bodyParagraph.paragraphSpacing = YapsTheme.textViewParagraphSpacing

        let headingParagraph = NSMutableParagraphStyle()
        headingParagraph.lineSpacing = 4
        headingParagraph.paragraphSpacing = 6
        headingParagraph.alignment = .center

        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: "\n\n")) }

            switch block.type {
            case .heading:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold, width: .standard),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: headingParagraph,
                ]
                result.append(NSAttributedString(string: block.text, attributes: attrs))

            case .paragraph:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: YapsTheme.textViewFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: bodyParagraph,
                ]
                result.append(NSAttributedString(string: block.text, attributes: attrs))
            }
        }

        return result
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: SelectableTextView

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            var range = textView.selectedRange
            guard range.length > 0 else {
                parent.onSelectionChange(nil)
                return
            }

            // Snap selection to word boundaries so partial-letter grabs still capture full words
            let nsText = textView.text as NSString
            let wordRange = nsText.wordRange(for: range)
            if wordRange != range {
                range = wordRange
                textView.selectedRange = range
            }

            let text = nsText.substring(with: range)

            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end)
            else {
                parent.onSelectionChange(nil)
                return
            }

            let uiKitRect = textView.firstRect(for: textRange)

            let visibleRect = CGRect(
                x: uiKitRect.origin.x - textView.contentOffset.x,
                y: uiKitRect.origin.y - textView.contentOffset.y,
                width: uiKitRect.width,
                height: uiKitRect.height
            )

            let selection = TextSelection(text: text, range: range, rect: visibleRect)
            parent.onSelectionChange(selection)
        }
    }
}
