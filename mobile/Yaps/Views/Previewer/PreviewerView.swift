import SwiftUI

struct PreviewerView: View {
    let ocrResult: OCRResult

    @State private var selection: TextSelection?
    @State private var translationResult: TranslationResult?
    @State private var showTranslationPopup = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var showBilingual = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showBilingual {
                BilingualTextView(blocks: ocrResult.blocks)
            } else {
                SelectableTextView(blocks: ocrResult.blocks) { newSelection in
                    handleSelectionChange(newSelection)
                }

                if showTranslationPopup, let selectedText = selection?.text ?? translationResult?.selectedText {
                    translationOverlay(selectedText: selectedText)
                }
            }
        }
        .navigationTitle("Перегляд")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showBilingual.toggle() }
                    if showBilingual { dismissPopup() }
                } label: {
                    Image(systemName: showBilingual ? "text.justify.leading" : "text.word.spacing")
                }
            }
        }
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
                    context: Self.surroundingSentence(
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

    private static func surroundingSentence(for range: NSRange, in fullText: String) -> String {
        let ns = fullText as NSString
        let sentenceRange = ns.paragraphRange(for: range)
        let paragraph = ns.substring(with: sentenceRange)

        guard let swiftRange = Range(range, in: fullText) else { return paragraph }
        let offset = fullText.distance(from: fullText.startIndex, to: swiftRange.lowerBound)
            - fullText.distance(from: fullText.startIndex, to: fullText.index(fullText.startIndex, offsetBy: sentenceRange.location))

        var best = paragraph[...]
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { _, substringRange, _, stop in
            let localEnd = paragraph.distance(from: paragraph.startIndex, to: substringRange.upperBound)
            if offset < localEnd {
                best = paragraph[substringRange]
                stop = true
            }
        }
        return String(best).trimmingCharacters(in: .whitespacesAndNewlines)
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
