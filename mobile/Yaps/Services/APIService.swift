import Foundation

actor APIService {
    static let shared = APIService()

    private let baseURL = AppConfig.apiBaseURL

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

    func translate(imageData: Data, languageHint: String? = nil) async throws -> TranslationResult {
        let url = URL(string: "\(baseURL)/api/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        await attachAuthHeader(to: &request)

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

        let decoded = try JSONDecoder().decode(TranslationResponse.self, from: data)

        if !decoded.success || decoded.content == nil {
            throw APIError.serverError(decoded.error ?? "Translation failed (HTTP \(http.statusCode))")
        }

        return TranslationResult(id: UUID(), content: decoded.content!)
    }

    private struct ErrorResponse: Decodable { let error: String? }

    func getAudio(text: String, language: String = "Polish") async throws -> Data {
        let url = URL(string: "\(baseURL)/api/audio")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await attachAuthHeader(to: &request)

        struct AudioRequest: Encodable {
            let text: String
            let language: String
        }

        request.httpBody = try JSONEncoder().encode(AudioRequest(text: text, language: language))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Audio generation failed")
            }
            throw APIError.serverError("Audio generation failed")
        }

        return data
    }

    func fetchOCRHistory() async throws -> [OCRHistoryItem] {
        let url = URL(string: "\(baseURL)/api/history/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        await attachAuthHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError("Failed to fetch history")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OCRHistoryResponse.self, from: data)
        return decoded.data ?? []
    }

    func deleteOCRHistory(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/history/ocr/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15
        await attachAuthHeader(to: &request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(err.error ?? "Delete failed")
            }
            throw APIError.serverError("Delete failed")
        }
    }

    nonisolated func loadSampleImage() -> Data? {
        guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Auth

    private func attachAuthHeader(to request: inout URLRequest) async {
        let token = await MainActor.run { AuthService.shared.accessToken }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
