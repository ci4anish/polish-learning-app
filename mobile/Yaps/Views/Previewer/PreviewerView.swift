import SwiftUI

struct PreviewerView: View {
    let translationResult: TranslationResult

    @State private var selectedText: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            BilingualTextView(blocks: translationResult.blocks) { text in
                withAnimation { selectedText = text }
            }

            if let text = selectedText {
                audioOverlay(text: text)
            }
        }
        .navigationTitle("Перегляд")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func audioOverlay(text: String) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(text)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(2)

                Spacer()

                Button {
                    YapsTheme.hapticTap()
                    withAnimation { selectedText = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            AudioButton(text: text)
                .frame(maxWidth: .infinity)
        }
        .padding(YapsTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: YapsTheme.cornerRadius))
        .padding(.horizontal, YapsTheme.padding)
        .padding(.bottom, YapsTheme.largePadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
