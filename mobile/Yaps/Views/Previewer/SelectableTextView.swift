import SwiftUI
import UIKit

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
            let range = textView.selectedRange
            guard range.length > 0 else {
                parent.onSelectionChange(nil)
                return
            }

            let text = (textView.text as NSString).substring(with: range)

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
