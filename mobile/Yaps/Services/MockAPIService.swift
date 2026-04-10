import Foundation

actor MockAPIService {
    static let shared = MockAPIService()

    func performOCR(image: Data?) async throws -> OCRResult {
        try await Task.sleep(for: .seconds(Double.random(in: 0.8...1.2)))

        return OCRResult(
            id: UUID(),
            fullText: """
            Cześć! Jak się masz? Dzisiaj jest piękny dzień. \
            Chciałbym pójść na spacer do parku. \
            Czy masz ochotę iść ze mną? \
            Możemy kupić lody po drodze. \
            Pogoda jest wspaniała, a park wygląda pięknie o tej porze roku.
            """,
            language: "pl",
            confidence: 0.95
        )
    }

    func explain(text: String) async throws -> ExplanationResult {
        try await Task.sleep(for: .seconds(Double.random(in: 0.8...1.2)))

        return ExplanationResult(
            id: UUID(),
            selectedText: text,
            translation: translationFor(text),
            partOfSpeech: "Adjective (Przymiotnik)",
            gender: "Masculine",
            grammaticalCase: "Nominative",
            declension: [
                .init(id: UUID(), caseName: "Nominative", singular: "piękny", plural: "piękni / piękne"),
                .init(id: UUID(), caseName: "Genitive", singular: "pięknego", plural: "pięknych"),
                .init(id: UUID(), caseName: "Dative", singular: "pięknemu", plural: "pięknym"),
                .init(id: UUID(), caseName: "Accusative", singular: "pięknego / piękny", plural: "pięknych / piękne"),
                .init(id: UUID(), caseName: "Instrumental", singular: "pięknym", plural: "pięknymi"),
                .init(id: UUID(), caseName: "Locative", singular: "pięknym", plural: "pięknych"),
                .init(id: UUID(), caseName: "Vocative", singular: "piękny", plural: "piękni / piękne"),
            ],
            examples: [
                .init(id: UUID(), polish: "To jest piękny dom.", english: "This is a beautiful house."),
                .init(id: UUID(), polish: "Jaki piękny zachód słońca!", english: "What a beautiful sunset!"),
                .init(id: UUID(), polish: "Piękny dzień na spacer.", english: "A beautiful day for a walk."),
            ]
        )
    }

    private func translationFor(_ text: String) -> String {
        let knownTranslations: [String: String] = [
            "piękny": "beautiful",
            "dzień": "day",
            "spacer": "walk",
            "park": "park",
            "lody": "ice cream",
            "pogoda": "weather",
            "wspaniała": "wonderful",
            "cześć": "hello / hi",
            "ochotę": "desire / willingness",
        ]
        let key = text.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return knownTranslations[key] ?? "beautiful (piękny)"
    }
}
