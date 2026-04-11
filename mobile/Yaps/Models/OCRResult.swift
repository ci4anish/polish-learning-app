import Foundation

struct TextBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(type)-\(original.prefix(40))" }
    let type: BlockType
    let original: String
    let translated: String

    enum BlockType: String, Codable, Sendable {
        case heading
        case paragraph
    }
}

struct OCRContent: Codable, Sendable {
    let detectedLanguage: String
    let blocks: [TextBlock]

    var fullText: String {
        blocks.map(\.original).joined(separator: " ")
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
