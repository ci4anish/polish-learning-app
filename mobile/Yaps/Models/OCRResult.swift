import Foundation

struct TextBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(type)-\(text.prefix(40))" }
    let type: BlockType
    let text: String

    enum BlockType: String, Codable, Sendable {
        case heading
        case paragraph
    }
}

struct OCRContent: Codable, Sendable {
    let detectedLanguage: String
    let blocks: [TextBlock]

    var fullText: String {
        blocks.map(\.text).joined(separator: "\n\n")
    }
}

struct OCRResponse: Codable, Sendable {
    let success: Bool
    let content: OCRContent?
    let provider: String?
    let model: String?
    let error: String?
}

struct OCRResult: Identifiable, Sendable {
    let id: UUID
    let content: OCRContent

    var fullText: String { content.fullText }
    var detectedLanguage: String { content.detectedLanguage }
    var blocks: [TextBlock] { content.blocks }
}
