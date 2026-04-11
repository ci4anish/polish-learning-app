import SwiftUI

struct PreviewerView: View {
    let ocrResult: OCRResult

    @State private var selection: TextSelection?
    @State private var translationResult: TranslationResult?
    @State private var showTranslationPopup = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .topLeading) {
            SelectableTextView(blocks: ocrResult.blocks) { newSelection in
                handleSelectionChange(newSelection)
            }

            if showTranslationPopup, let selectedText = selection?.text ?? translationResult?.selectedText {
                translationOverlay(selectedText: selectedText)
            }
        }
        .navigationTitle("Перегляд")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func translationOverlay(selectedText: String) -> some View {
        VStack {
            Spacer()
            TranslationPopup(
                selectedText: selectedText,
                translation: translationResult,
                onDismiss: { dismissPopup() }
            )
            .padding(.horizontal, YapsTheme.padding)
            .padding(.bottom, YapsTheme.largePadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: showTranslationPopup)
    }

    private func handleSelectionChange(_ newSelection: TextSelection?) {
        if newSelection == nil {
            debounceTask?.cancel()
            if showTranslationPopup {
                dismissPopup()
            } else {
                selection = nil
            }
        } else {
            selection = newSelection
            scheduleTranslate(for: newSelection!)
        }
    }

    private func scheduleTranslate(for newSelection: TextSelection) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            translationResult = nil
            withAnimation { showTranslationPopup = true }

            do {
                let result = try await APIService.shared.translate(
                    text: newSelection.text,
                    context: Self.surroundingContext(
                        for: newSelection.range,
                        in: ocrResult.fullText
                    )
                )
                guard !Task.isCancelled else { return }
                withAnimation { translationResult = result }
                YapsTheme.hapticSuccess()
            } catch {
                print("[Previewer] translate failed:", error.localizedDescription)
                dismissPopup()
            }
        }
    }

    /// Extracts ~200 characters of surrounding text centered on the selection range.
    private static func surroundingContext(for range: NSRange, in fullText: String, radius: Int = 100) -> String {
        let ns = fullText as NSString
        let center = range.location + range.length / 2
        let start = max(0, center - radius)
        let end = min(ns.length, center + radius)
        return ns.substring(with: NSRange(location: start, length: end - start))
    }

    private func dismissPopup() {
        debounceTask?.cancel()
        withAnimation {
            showTranslationPopup = false
            translationResult = nil
            selection = nil
        }
    }
}
