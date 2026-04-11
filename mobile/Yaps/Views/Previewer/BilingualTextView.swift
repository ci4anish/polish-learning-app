import SwiftUI

struct BilingualTextView: View {
    let blocks: [TextBlock]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.original)
                            .font(originalFont(for: block.type))
                            .foregroundStyle(.primary)

                        Text(block.translated)
                            .font(translatedFont(for: block.type))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, YapsTheme.padding)
            .padding(.vertical, 20)
        }
    }

    private func originalFont(for type: TextBlock.BlockType) -> Font {
        switch type {
        case .heading:
            .system(.title2, design: .rounded, weight: .bold)
        case .paragraph:
            .system(size: 18, weight: .regular, design: .rounded)
        }
    }

    private func translatedFont(for type: TextBlock.BlockType) -> Font {
        switch type {
        case .heading:
            .system(.title3, design: .rounded, weight: .medium)
        case .paragraph:
            .system(size: 17, weight: .regular, design: .rounded)
        }
    }
}
