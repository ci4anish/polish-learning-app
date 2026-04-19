import SwiftUI

@Observable
final class OCRViewModel: @unchecked Sendable {
    private(set) var blocks: [TextBlock] = []
    private(set) var detectedLanguage: String = ""
    private(set) var isLoading = true
    private(set) var error: String?

    init() {}

    init(blocks: [TextBlock], detectedLanguage: String) {
        self.blocks = blocks
        self.detectedLanguage = detectedLanguage
        self.isLoading = false
    }

    func startOCR(imageData: Data, languageHint: String? = nil) {
        isLoading = true
        error = nil
        blocks = []

        Task {
            do {
                let languages = [languageHint ?? "pl"]
                let result = try await VisionOCRService.recognizeText(from: imageData, languages: languages)

                await MainActor.run {
                    self.detectedLanguage = result.detectedLanguage
                    self.blocks = result.blocks
                }

                await MainActor.run { self.isLoading = false }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
