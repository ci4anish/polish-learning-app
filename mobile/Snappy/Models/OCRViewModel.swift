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
                let stream = try await APIService.shared.streamOCR(imageData: imageData, languageHint: languageHint)
                for try await event in stream {
                    switch event {
                    case .meta(let lang):
                        await MainActor.run { self.detectedLanguage = lang }
                    case .block(let block):
                        await MainActor.run {
                            withAnimation(.easeIn(duration: 0.3)) {
                                self.blocks.append(block)
                            }
                        }
                    case .error(let msg):
                        await MainActor.run { self.error = msg }
                    case .done:
                        break
                    }
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
