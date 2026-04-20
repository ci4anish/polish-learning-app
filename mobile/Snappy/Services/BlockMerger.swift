import Foundation
import CoreGraphics

/// Converts raw Vision OCR lines into `TextBlock`s.
///
/// Currently a 1:1 mapping (one line per block, no merging). This is the
/// integration point where AI-driven merge logic will plug in.
enum BlockMerger {

    static func makeBlocks(_ lines: [RecognizedLine]) -> [TextBlock] {
        guard !lines.isEmpty else { return [] }

        let maxHeight = lines.map(\.height).max() ?? 1

        return lines.map { line in
            let relativeHeight = line.height / maxHeight
            return TextBlock(
                type: .paragraph,
                relativeHeight: relativeHeight,
                original: line.text
            )
        }
    }
}
