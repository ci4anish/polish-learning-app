import SwiftUI

struct PreviewerView: View {
    let ocrResult: OCRResult

    @State private var selection: TextSelection?
    @State private var magicState: MagicButtonState = .idle
    @State private var explanationResult: ExplanationResult?
    @State private var showTranslationPopup = false
    @State private var showGrammarDetail = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            SelectableTextView(blocks: ocrResult.blocks) { newSelection in
                handleSelectionChange(newSelection)
            }

            if let selection, !showTranslationPopup {
                MagicButton(state: magicState) {
                    fetchExplanation(for: selection.text)
                }
                .offset(
                    x: clampX(selection.rect.midX - 30),
                    y: selection.rect.maxY + 12
                )
            }

            if showTranslationPopup, let result = explanationResult {
                translationOverlay(result: result)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGrammarDetail) {
            if let result = explanationResult {
                GrammarDetailView(result: result)
            }
        }
    }

    @ViewBuilder
    private func translationOverlay(result: ExplanationResult) -> some View {
        VStack {
            Spacer()

            TranslationPopup(
                result: result,
                onExpand: {
                    showGrammarDetail = true
                },
                onDismiss: {
                    dismissPopup()
                }
            )
            .padding(.horizontal, YapsTheme.padding)
            .padding(.bottom, YapsTheme.largePadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: showTranslationPopup)
    }

    private func handleSelectionChange(_ newSelection: TextSelection?) {
        if newSelection == nil {
            if !showTranslationPopup {
                selection = nil
                magicState = .idle
            }
        } else {
            dismissPopup()
            selection = newSelection
            magicState = .idle
        }
    }

    private func fetchExplanation(for text: String) {
        magicState = .thinking
        Task {
            do {
                let result = try await APIService.shared.explain(
                    text: text,
                    sourceLanguage: ocrResult.detectedLanguage,
                    context: ocrResult.fullText
                )
                explanationResult = result
                magicState = .done
                YapsTheme.hapticSuccess()
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation { showTranslationPopup = true }
            } catch {
                print("[Previewer] explain failed:", error.localizedDescription)
                magicState = .idle
            }
        }
    }

    private func dismissPopup() {
        withAnimation {
            showTranslationPopup = false
            explanationResult = nil
            magicState = .idle
        }
    }

    private func clampX(_ x: CGFloat) -> CGFloat {
        max(16, min(x, UIScreen.main.bounds.width - 80))
    }
}
