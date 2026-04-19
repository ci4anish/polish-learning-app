import SwiftUI

@Observable
final class OCRViewModel: @unchecked Sendable {
    private(set) var blocks: [TextBlock] = []
    private(set) var detectedLanguage: String = ""
    private(set) var isLoading = true
    private(set) var isEnhancing = false
    private(set) var error: String?

    init() {}

    init(blocks: [TextBlock], detectedLanguage: String) {
        self.blocks = blocks
        self.detectedLanguage = detectedLanguage
        self.isLoading = false
    }

    func startOCR(imageData: Data, languageHint: String? = nil) {
        isLoading = true
        isEnhancing = false
        error = nil
        blocks = []

        Task {
            do {
                let languages = [languageHint ?? "pl"]
                let result = try await VisionOCRService.recognizeText(from: imageData, languages: languages)

                let visionBlocks = result.blocks
                await MainActor.run {
                    self.detectedLanguage = result.detectedLanguage
                    self.blocks = visionBlocks
                    self.isLoading = false
                }

                let useLocalAI = UserDefaults.standard.bool(forKey: "useLocalAI")
                guard useLocalAI else { return }

                let llmReady = await MainActor.run { LocalLLMService.shared.state == .ready }
                guard llmReady else { return }

                await MainActor.run { self.isEnhancing = true }

                do {
                    let enhanced = try await LocalLLMService.shared.enhance(
                        blocks: visionBlocks, language: result.detectedLanguage
                    )
                    await MainActor.run {
                        self.blocks = enhanced
                        self.isEnhancing = false
                    }
                } catch {
                    await MainActor.run { self.isEnhancing = false }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
