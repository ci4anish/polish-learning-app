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
    let text: String
    let onSelectionChange: (TextSelection?) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = MenuFreeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 80, right: 16)
        textView.showsVerticalScrollIndicator = false
        textView.delegate = context.coordinator

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = YapsTheme.textViewLineSpacing
        paragraphStyle.paragraphSpacing = YapsTheme.textViewParagraphSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: YapsTheme.textViewFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle,
        ]

        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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

            // Convert from UITextView content coordinates to the view's visible coordinates
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
