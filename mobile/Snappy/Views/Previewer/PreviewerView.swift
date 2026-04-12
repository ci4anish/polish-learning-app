import SwiftUI

struct PreviewerView: View {
    @Bindable var viewModel: OCRViewModel

    @State private var selection: TextSelection?
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var translateError: String?
    @State private var translateTask: Task<Void, Never>?
    @State private var chatViewModel: ChatViewModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.blocks.isEmpty && viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error, viewModel.blocks.isEmpty {
                errorView(error)
            } else {
                BlockTextView(blocks: viewModel.blocks) { newSelection in
                    withAnimation { selection = newSelection }
                }
            }

            if viewModel.isLoading && !viewModel.blocks.isEmpty {
                streamingIndicator
            }

            if let sel = selection {
                selectionOverlay(selection: sel)
            }
        }
        .navigationTitle("Перегляд")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $chatViewModel) { vm in
            ChatView(viewModel: vm)
        }
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
                        sourceLanguage: viewModel.detectedLanguage
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Аналізую текст…")
                .font(AppTheme.headlineFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var streamingIndicator: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Читаю далі…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    AppTheme.hapticTap()
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

            HStack(spacing: 10) {
                AudioButton(text: selection.text)

                Button {
                    AppTheme.hapticTap()
                    chatViewModel = ChatViewModel(
                        selectedText: selection.text,
                        context: selection.sentenceContext != selection.text ? selection.sentenceContext : nil,
                        sourceLanguage: viewModel.detectedLanguage
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Репетитор")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(AppTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.cornerRadius))
        .padding(.horizontal, AppTheme.padding)
        .padding(.bottom, AppTheme.largePadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
