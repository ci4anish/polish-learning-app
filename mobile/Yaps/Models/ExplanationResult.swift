import Foundation

struct ExplanationResult: Codable, Identifiable, Sendable {
    let id: UUID
    let selectedText: String
    let translation: String
    let partOfSpeech: String
    let gender: String?
    let grammaticalCase: String?
    let declension: [DeclensionEntry]?
    let examples: [Example]

    struct DeclensionEntry: Codable, Identifiable, Sendable {
        let id: UUID
        let caseName: String
        let singular: String
        let plural: String
    }

    struct Example: Codable, Identifiable, Sendable {
        let id: UUID
        let polish: String
        let english: String
    }
}
