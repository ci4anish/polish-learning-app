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

private let originalRangesKey = NSAttributedString.Key("blockTextOriginalRanges")

private class MenuFreeTextView: UITextView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        nil
    }
}

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

struct TextSelection: Equatable {
    let text: String
    let sentenceContext: String
}

struct BlockTextView: UIViewRepresentable {
    let blocks: [TextBlock]
    var onSelectionChange: ((TextSelection?) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = MenuFreeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 100, right: 16)
        textView.showsVerticalScrollIndicator = false
        textView.delegate = context.coordinator

        let (attrString, ranges) = Self.buildAttributedString(from: blocks)
        textView.attributedText = attrString
        context.coordinator.originalRanges = ranges

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
            let isGrowing = blocks.count > context.coordinator.previousBlocks.count
            context.coordinator.previousBlocks = blocks
            let (attrString, ranges) = Self.buildAttributedString(from: blocks)

            if isGrowing {
                UIView.transition(with: uiView, duration: 0.25, options: .transitionCrossDissolve) {
                    uiView.attributedText = attrString
                }
            } else {
                uiView.attributedText = attrString
            }
            context.coordinator.originalRanges = ranges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func buildAttributedString(from blocks: [TextBlock]) -> (NSAttributedString, [NSRange]) {
        let result = NSMutableAttributedString()
        var originalRanges: [NSRange] = []

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 14

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle,
        ]

        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: "\n")) }

            let originalStart = result.length
            result.append(NSAttributedString(string: block.original, attributes: attrs))

            originalRanges.append(NSRange(location: originalStart, length: result.length - originalStart))
        }

        return (result, originalRanges)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: BlockTextView
        var previousBlocks: [TextBlock]
        var originalRanges: [NSRange] = []
        private var isAdjustingSelection = false
        private var isTouching = false
        private var needsEmit = false

        init(_ parent: BlockTextView) {
            self.parent = parent
            self.previousBlocks = parent.blocks
        }

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

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isAdjustingSelection else { return }

            if textView.selectedRange.length > 0 {
                let clamped = clampToOriginalRanges(textView.selectedRange, in: textView.text as NSString)

                if let clamped {
                    let nsText = textView.text as NSString
                    let wordRange = nsText.wordRange(for: clamped)
                    let finalRange = clampToOriginalRanges(wordRange, in: nsText) ?? clamped

                    if finalRange != textView.selectedRange {
                        isAdjustingSelection = true
                        textView.selectedRange = finalRange
                        isAdjustingSelection = false
                    }
                } else {
                    isAdjustingSelection = true
                    textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
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

        private func clampToOriginalRanges(_ range: NSRange, in text: NSString) -> NSRange? {
            let selStart = range.location
            let selEnd = range.location + range.length

            var bestStart = Int.max
            var bestEnd = 0
            var hasOverlap = false

            for origRange in originalRanges {
                let origStart = origRange.location
                let origEnd = origRange.location + origRange.length

                if selStart < origEnd && selEnd > origStart {
                    hasOverlap = true
                    bestStart = min(bestStart, max(selStart, origStart))
                    bestEnd = max(bestEnd, min(selEnd, origEnd))
                }
            }

            guard hasOverlap, bestEnd > bestStart else { return nil }
            return NSRange(location: bestStart, length: bestEnd - bestStart)
        }

        private func emitSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0 else {
                parent.onSelectionChange?(nil)
                return
            }

            let nsText = textView.text as NSString
            let selectedText = nsText.substring(with: range)

            let blockContext: String
            if let blockRange = originalRanges.first(where: {
                range.location >= $0.location &&
                range.location + range.length <= $0.location + $0.length
            }) {
                blockContext = nsText.substring(with: blockRange)
            } else {
                blockContext = selectedText
            }

            parent.onSelectionChange?(TextSelection(text: selectedText, sentenceContext: blockContext))
        }
    }
}
