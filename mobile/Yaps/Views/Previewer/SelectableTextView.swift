import SwiftUI
import UIKit

private let wordExtraChars = CharacterSet(charactersIn: "-'")

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
        return CharacterSet.letters.contains(scalar) || wordExtraChars.contains(scalar)
    }
}

struct TextSelection: Equatable {
    let text: String
    let range: NSRange
    let rect: CGRect
}

/// Passive gesture recognizer that tracks touch lifecycle without
/// interfering with UITextView's own selection gestures.
private class TouchObserver: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .began
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .ended
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
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

        let touchObserver = TouchObserver(
            target: context.coordinator,
            action: #selector(Coordinator.handleTouch(_:))
        )
        touchObserver.cancelsTouchesInView = false
        touchObserver.delaysTouchesBegan = false
        touchObserver.delaysTouchesEnded = false
        touchObserver.delegate = context.coordinator
        textView.addGestureRecognizer(touchObserver)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if blocks != context.coordinator.previousBlocks {
            context.coordinator.previousBlocks = blocks
            uiView.attributedText = Self.buildAttributedString(from: blocks)
        }
    }

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
                result.append(NSAttributedString(string: block.original, attributes: attrs))

            case .paragraph:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: YapsTheme.textViewFont,
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: bodyParagraph,
                ]
                result.append(NSAttributedString(string: block.original, attributes: attrs))
            }
        }

        return result
    }

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: SelectableTextView
        var previousBlocks: [TextBlock]
        private var isAdjustingSelection = false
        private var isTouching = false
        private var needsEmit = false

        init(_ parent: SelectableTextView) {
            self.parent = parent
            self.previousBlocks = parent.blocks
        }

        // MARK: - Touch tracking

        @objc func handleTouch(_ gesture: UIGestureRecognizer) {
            switch gesture.state {
            case .began:
                isTouching = true
            case .ended, .cancelled, .failed:
                isTouching = false
                if needsEmit, let textView = gesture.view as? UITextView {
                    needsEmit = false
                    emitSelection(textView)
                }
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // MARK: - Selection

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isAdjustingSelection else { return }

            if textView.selectedRange.length > 0 {
                let nsText = textView.text as NSString
                let wordRange = nsText.wordRange(for: textView.selectedRange)
                if wordRange != textView.selectedRange {
                    isAdjustingSelection = true
                    textView.selectedRange = wordRange
                    isAdjustingSelection = false
                }
            }

            if isTouching {
                needsEmit = true
            } else {
                needsEmit = false
                emitSelection(textView)
            }
        }

        private func emitSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else {
                parent.onSelectionChange(nil)
                return
            }

            let nsText = textView.text as NSString
            let text = nsText.substring(with: range)

            guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
                  let end = textView.position(from: start, offset: range.length),
                  let textRange = textView.textRange(from: start, to: end)
            else {
                parent.onSelectionChange(nil)
                return
            }

            let rects = textView.selectionRects(for: textRange)
            let uiKitRect = rects.reduce(CGRect.null) { $0.union($1.rect) }

            guard !uiKitRect.isNull else {
                parent.onSelectionChange(nil)
                return
            }

            let visibleRect = uiKitRect.offsetBy(
                dx: -textView.contentOffset.x,
                dy: -textView.contentOffset.y
            )

            let selection = TextSelection(text: text, range: range, rect: visibleRect)
            parent.onSelectionChange(selection)
        }
    }
}
