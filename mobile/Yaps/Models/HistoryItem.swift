import Foundation

struct OCRHistoryItem: Codable, Identifiable, Sendable {
    let id: String
    let detectedLanguage: String
    let blocks: [TextBlock]
    let model: String
    let provider: String
    let createdAt: Date

    var fullText: String {
        blocks.map(\.text).joined(separator: "\n\n")
    }

    var preview: String {
        let text = blocks.first?.text ?? ""
        return text.count > 120 ? String(text.prefix(120)) + "…" : text
    }

    enum CodingKeys: String, CodingKey {
        case id
        case detectedLanguage = "detected_language"
        case blocks
        case model
        case provider
        case createdAt = "created_at"
    }
}

struct OCRHistoryResponse: Codable, Sendable {
    let success: Bool
    let data: [OCRHistoryItem]?
    let error: String?
}
