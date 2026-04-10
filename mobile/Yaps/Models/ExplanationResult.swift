import Foundation

struct ExplainResponse: Codable, Sendable {
    let success: Bool
    let explanation: ExplainContent?
    let error: String?

    struct ExplainContent: Codable, Sendable {
        let selectedText: String
        let translation: String
        let partOfSpeech: String
        let gender: String?
        let grammaticalCase: String?
        let declension: [DeclensionEntry]?
        let examples: [ExampleEntry]

        struct DeclensionEntry: Codable, Sendable {
            let caseName: String
            let singular: String
            let plural: String
        }

        struct ExampleEntry: Codable, Sendable {
            let source: String
            let target: String
        }
    }
}

struct ExplanationResult: Identifiable, Sendable {
    let id = UUID()
    let selectedText: String
    let translation: String
    let partOfSpeech: String
    let gender: String?
    let grammaticalCase: String?
    let declension: [DeclensionEntry]?
    let examples: [Example]

    struct DeclensionEntry: Identifiable, Sendable {
        var id: String { caseName }
        let caseName: String
        let singular: String
        let plural: String
    }

    struct Example: Identifiable, Sendable {
        var id: String { source }
        let source: String
        let target: String
    }

    init(from response: ExplainResponse.ExplainContent) {
        self.selectedText = response.selectedText
        self.translation = response.translation
        self.partOfSpeech = response.partOfSpeech
        self.gender = response.gender
        self.grammaticalCase = response.grammaticalCase
        self.declension = response.declension?.map {
            DeclensionEntry(caseName: $0.caseName, singular: $0.singular, plural: $0.plural)
        }
        self.examples = response.examples.map {
            Example(source: $0.source, target: $0.target)
        }
    }
}
