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

/// One line as returned by Vision, in normalised image coordinates
/// (0,0 = bottom-left, 1,1 = top-right — Vision's default).
struct RecognizedLine: Sendable, Equatable {
    let text: String
    let boundingBox: CGRect
    var height: CGFloat { boundingBox.height }
}

struct VisionOCRService {

    static func recognizeText(
        from imageData: Data,
        languages: [String] = ["pl"]
    ) async throws -> (lines: [RecognizedLine], detectedLanguage: String) {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw VisionOCRError.invalidImage
        }

        let lines = try await performRecognition(on: cgImage, languages: languages)
        let detectedLanguage = languages.first ?? "pl"
        return (lines, detectedLanguage)
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
                    return RecognizedLine(text: candidate.string, boundingBox: obs.boundingBox)
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
}
