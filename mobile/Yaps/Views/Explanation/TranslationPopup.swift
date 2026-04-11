import SwiftUI

struct TranslationPopup: View {
    let selectedText: String
    let translation: TranslationResult?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            content
        }
        .padding(YapsTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: YapsTheme.cornerRadius))
    }

    private var header: some View {
        HStack {
            Text(selectedText)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .lineLimit(2)

            Spacer()

            Button {
                YapsTheme.hapticTap()
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let translation {
            VStack(alignment: .leading, spacing: 14) {
                Text(translation.partOfSpeech)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Переклад")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(translation.translation)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                    }
                }

                AudioButton(text: selectedText)
                    .frame(maxWidth: .infinity)
            }
            .transition(.opacity)
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text("Перекладаю…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .transition(.opacity)
        }
    }
}
