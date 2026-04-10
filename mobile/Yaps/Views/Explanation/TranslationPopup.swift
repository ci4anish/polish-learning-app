import SwiftUI

struct TranslationPopup: View {
    let result: ExplanationResult
    let onExpand: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.selectedText)
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    Text(result.partOfSpeech)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }

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

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "character.book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Translation")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(result.translation)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                }
            }

            if let gender = result.gender {
                HStack(spacing: 4) {
                    Label(gender, systemImage: "person.fill")
                    if let gramCase = result.grammaticalCase {
                        Text("·")
                        Text(gramCase)
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    YapsTheme.hapticTap()
                    onExpand()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed")
                        Text("Grammar Details")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glass)

                AudioButton()
            }
        }
        .padding(YapsTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: YapsTheme.cornerRadius))
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                appeared = true
            }
        }
    }
}
