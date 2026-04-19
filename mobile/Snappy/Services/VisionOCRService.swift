import Vision
import UIKit

enum VisionOCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not create image from provided data"
        case .recognitionFailed(let msg): msg
        }
    }
}

struct VisionOCRService {

    private struct RecognizedLine: Sendable {
        let text: String
        let boundingBoxHeight: CGFloat
    }

    static func recognizeText(
        from imageData: Data,
        languages: [String] = ["pl"]
    ) async throws -> (blocks: [TextBlock], detectedLanguage: String) {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw VisionOCRError.invalidImage
        }

        let lines = try await performRecognition(on: cgImage, languages: languages)
        let blocks = buildBlocks(from: lines)
        let detectedLanguage = languages.first ?? "pl"

        return (blocks, detectedLanguage)
    }

    private static func performRecognition(
        on image: CGImage,
        languages: [String]
    ) async throws -> [RecognizedLine] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: VisionOCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { obs -> RecognizedLine? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return RecognizedLine(text: candidate.string, boundingBoxHeight: obs.boundingBox.height)
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: VisionOCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    private static func buildBlocks(from lines: [RecognizedLine]) -> [TextBlock] {
        guard !lines.isEmpty else { return [] }

        let maxHeight = lines.map(\.boundingBoxHeight).max() ?? 1

        return lines.map { line in
            let relativeHeight = line.boundingBoxHeight / maxHeight
            return TextBlock(type: .paragraph, relativeHeight: relativeHeight, original: line.text)
        }
    }
}
