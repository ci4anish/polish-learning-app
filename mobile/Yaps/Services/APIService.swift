import Foundation

actor APIService {
    static let shared = APIService()

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:8787"
    #else
    private let baseURL = "http://localhost:8787"
    #endif

    enum APIError: LocalizedError {
        case invalidResponse
        case serverError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Invalid server response"
            case .serverError(let msg): msg
            case .networkError(let err): err.localizedDescription
            }
        }
    }

    func performOCR(imageData: Data, languageHint: String? = nil) async throws -> OCRResult {
        let url = URL(string: "\(baseURL)/api/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.appendMultipart(boundary: boundary, name: "image", filename: "photo.jpg", mimeType: "image/jpeg", data: imageData)

        if let hint = languageHint {
            body.appendMultipart(boundary: boundary, name: "languageHint", value: hint)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(OCRResponse.self, from: data)

        if !decoded.success || decoded.content == nil {
            throw APIError.serverError(decoded.error ?? "OCR failed (HTTP \(http.statusCode))")
        }

        return OCRResult(id: UUID(), content: decoded.content!)
    }

    nonisolated func loadSampleImage() -> Data? {
        guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }
}

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append("\r\n".data(using: .utf8)!)
    }
}
