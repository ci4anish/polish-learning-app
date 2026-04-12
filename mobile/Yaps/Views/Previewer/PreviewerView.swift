import SwiftUI

struct PreviewerView: View {
    let translationResult: TranslationResult

    @State private var selection: TextSelection?
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var translateError: String?
    @State private var translateTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            BlockTextView(blocks: translationResult.blocks) { newSelection in
                withAnimation { selection = newSelection }
            }

            if let sel = selection {
                selectionOverlay(selection: sel)
            }
        }
        .navigationTitle("Перегляд")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selection) { _, newValue in
            translateTask?.cancel()
            translatedText = nil
            translateError = nil

            guard let sel = newValue else {
                isTranslating = false
                return
            }

            isTranslating = true
            translateTask = Task {
                do {
                    let context = sel.sentenceContext != sel.text ? sel.sentenceContext : nil
                    let result = try await APIService.shared.translateText(
                        text: sel.text,
                        context: context,
                        sourceLanguage: translationResult.detectedLanguage
                    )
                    guard !Task.isCancelled else { return }
                    translatedText = result
                } catch {
                    guard !Task.isCancelled else { return }
                    translateError = error.localizedDescription
                }
                isTranslating = false
            }
        }
    }

    @ViewBuilder
    private func selectionOverlay(selection: TextSelection) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(selection.text)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(2)

                Spacer()

                Button {
                    YapsTheme.hapticTap()
                    withAnimation { self.selection = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Перекладаю…")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let translated = translatedText {
                Text(translated)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = translateError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            AudioButton(text: selection.text)
                .frame(maxWidth: .infinity)
        }
        .padding(YapsTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: YapsTheme.cornerRadius))
        .padding(.horizontal, YapsTheme.padding)
        .padding(.bottom, YapsTheme.largePadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
