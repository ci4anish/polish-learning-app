import Foundation

actor MockAPIService {
    static let shared = MockAPIService()

    func performOCR(image: Data?) async throws -> OCRResult {
        try await Task.sleep(for: .seconds(Double.random(in: 0.8...1.2)))

        return OCRResult(
            id: UUID(),
            content: OCRContent(
                detectedLanguage: "pl",
                blocks: [
                    .init(
                        type: .heading,
                        text: "SŁOWO WSTĘPNE"
                    ),
                    .init(
                        type: .paragraph,
                        text: #"Z czcią i wzruszeniem oddajemy tę książkę w ręce Żołnierza Polskiego. Na wiele już lat przed tą wojną była ona wielką rzadkością w Polsce, „białym krukiem", o którego posiadanie zabiegali zbieracze i niejedna biblioteka."#
                    ),
                    .init(
                        type: .paragraph,
                        text: "Niezwykłe koleje losu wyrzuciły ją w chwili obecnej na tę wyspę daleką, gdzie od pięciu lat z górą przebywa Żołnierz Polski."
                    ),
                    .init(
                        type: .paragraph,
                        text: "W 1915 roku, gdy wykuwał się w ciężkim mozole Zbrojny Czyn Oręża Polskiego, Kazimierz Przerwa Tetmajer stanął u boku młodego Żołnierza-Bojownika o Wolność i Niepodległość Polski."
                    ),
                ]
            )
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
