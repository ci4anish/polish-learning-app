import Foundation

struct TextBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(relativeHeight)-\(original.prefix(40))" }
    let relativeHeight: CGFloat
    let original: String
}

struct TranslationContent: Codable, Sendable {
    let detectedLanguage: String
    let blocks: [TextBlock]

    var fullText: String {
        blocks.map(\.original).joined(separator: " ")
    }
}

struct TranslationResponse: Codable, Sendable {
    let success: Bool
    let content: TranslationContent?
    let provider: String?
    let model: String?
    let error: String?
}

struct TranslationResult: Identifiable, Sendable {
    let id: UUID
    let content: TranslationContent

    var fullText: String { content.fullText }
    var detectedLanguage: String { content.detectedLanguage }
    var blocks: [TextBlock] { content.blocks }
}
