import Foundation

struct OCRResult: Codable, Identifiable, Sendable {
    let id: UUID
    let fullText: String
    let language: String
    let confidence: Double
}
