import SwiftUI

/// Summary of what the AI classifier produced — surfaced in the UI so the
/// user can actually see whether AI ran and what it changed.
struct AIEnhancementSummary: Equatable, Sendable {
    let headings: Int
    let paragraphs: Int
    let mergedFromLines: Int
}

@Observable
final class OCRViewModel: @unchecked Sendable {
    private(set) var blocks: [TextBlock] = []
    private(set) var detectedLanguage: String = ""
    private(set) var isLoading = true
    private(set) var isEnhancing = false
    private(set) var error: String?
    private(set) var enhancementSummary: AIEnhancementSummary?
    private(set) var enhancementError: String?

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
        enhancementSummary = nil
        enhancementError = nil
        blocks = []

        Task {
            do {
                let languages = [languageHint ?? "pl"]
                let result = try await VisionOCRService.recognizeText(from: imageData, languages: languages)

                let mergedBlocks = BlockMerger.makeBlocks(result.lines)
                let rawLineCount = result.lines.count

                await MainActor.run {
                    self.detectedLanguage = result.detectedLanguage
                    self.blocks = mergedBlocks
                    self.isLoading = false
                }

                let useLocalAI = UserDefaults.standard.bool(forKey: "useLocalAI")
                guard useLocalAI else { return }

                let canEnhance = await MainActor.run { () -> Bool in
                    let svc = LocalLLMService.shared
                    switch svc.status(for: svc.ocrModel) {
                    case .ready, .downloaded: return true
                    default: return false
                    }
                }
                guard canEnhance else { return }

                await MainActor.run { self.isEnhancing = true }

                do {
                    let classified = try await LocalLLMService.shared.classify(blocks: mergedBlocks)
                    let summary = AIEnhancementSummary(
                        headings: classified.filter { $0.type == .heading }.count,
                        paragraphs: classified.filter { $0.type == .paragraph }.count,
                        mergedFromLines: rawLineCount
                    )
                    await MainActor.run {
                        self.blocks = classified
                        self.enhancementSummary = summary
                        self.isEnhancing = false
                    }
                } catch {
                    await MainActor.run {
                        self.enhancementError = error.localizedDescription
                        self.isEnhancing = false
                    }
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
