import SwiftUI
import Translation

struct PreviewerView: View {
    @Bindable var viewModel: OCRViewModel

    @Environment(AuthService.self) private var auth
    @State private var selection: TextSelection?
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var isEnhancingTranslation = false
    @State private var translationEnhancedByAI = false
    @State private var translateError: String?
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translationEnhanceTask: Task<Void, Never>?
    @State private var chatViewModel: ChatViewModel?

    @AppStorage("useLocalAITranslation") private var useLocalAITranslation = false

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

            if viewModel.isEnhancing {
                enhancingIndicator
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
            translationEnhanceTask?.cancel()
            translationEnhanceTask = nil
            translatedText = nil
            translateError = nil
            isEnhancingTranslation = false
            translationEnhancedByAI = false

            guard newValue != nil else {
                isTranslating = false
                return
            }

            isTranslating = true

            let source = Locale.Language(identifier: viewModel.detectedLanguage ?? "pl")
            let target = Locale.Language(identifier: "uk")

            if translationConfig == nil {
                translationConfig = .init(source: source, target: target)
            } else {
                translationConfig?.source = source
                translationConfig?.target = target
                translationConfig?.invalidate()
            }
        }
        .translationTask(translationConfig) { session in
            nonisolated(unsafe) let session = session
            guard let sel = selection else { return }
            do {
                let response = try await session.translate(sel.text)
                translatedText = response.targetText
                isTranslating = false
                scheduleTranslationEnhancement(for: sel, draft: response.targetText)
            } catch {
                translateError = error.localizedDescription
                isTranslating = false
            }
        }
        .onDisappear {
            translationEnhanceTask?.cancel()
            translationEnhanceTask = nil
        }
    }

    private func scheduleTranslationEnhancement(for sel: TextSelection, draft: String) {
        guard useLocalAITranslation else { return }
        guard LocalLLMService.shared.state == .ready else { return }

        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sourceLanguage = viewModel.detectedLanguage ?? "pl"
        let context = sel.sentenceContext != sel.text ? sel.sentenceContext : nil

        isEnhancingTranslation = true
        translationEnhancedByAI = false

        translationEnhanceTask = Task { @MainActor in
            do {
                let improved = try await LocalLLMService.shared.enhanceTranslation(
                    selection: sel.text,
                    context: context,
                    draft: draft,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: "uk"
                )
                guard !Task.isCancelled, selection == sel else { return }
                if !improved.isEmpty && improved != draft {
                    translatedText = improved
                    translationEnhancedByAI = true
                }
            } catch {
                // Keep Apple's draft on failure; do not surface error to UI.
            }
            isEnhancingTranslation = false
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

    private var enhancingIndicator: some View {
        VStack {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Покращую за допомогою AI…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, 12)
            Spacer()
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(translated)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isEnhancingTranslation {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Покращую переклад за допомогою AI…")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    } else if translationEnhancedByAI {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("Покращено AI")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(.tint)
                    }
                }
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
                        Image(systemName: auth.isAuthenticated ? "sparkles" : "lock.fill")
                        Text("Репетитор")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .disabled(!auth.isAuthenticated)
                .opacity(auth.isAuthenticated ? 1.0 : 0.55)
            }

            if !auth.isAuthenticated {
                Text("Увійдіть у вкладці «Профіль», щоб користуватися аудіо та AI-репетитором.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppTheme.padding)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.cornerRadius))
        .padding(.horizontal, AppTheme.padding)
        .padding(.bottom, AppTheme.largePadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
