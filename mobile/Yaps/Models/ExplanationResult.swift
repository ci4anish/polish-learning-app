import Foundation

struct TranslateResponse: Codable, Sendable {
    let success: Bool
    let translation: TranslateContent?
    let error: String?

    struct TranslateContent: Codable, Sendable {
        let selectedText: String
        let translation: String
    }
}

struct TranslationResult: Equatable, Sendable {
    let selectedText: String
    let translation: String

    init(from content: TranslateResponse.TranslateContent) {
        self.selectedText = content.selectedText
        self.translation = content.translation
    }
}
