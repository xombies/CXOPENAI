import Foundation

struct OllamaClient {
    struct ClientError: LocalizedError {
        enum Kind {
            case invalidServerURL(String)
            case requestFailed(Int, String)
        }

        let kind: Kind

        var errorDescription: String? {
            switch kind {
            case .invalidServerURL(let value):
                return "Invalid server URL: \(value)"
            case .requestFailed(let statusCode, let message):
                return "Ollama request failed (\(statusCode)): \(message)"
            }
        }
    }

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    static func parseBaseURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClientError(kind: .invalidServerURL(rawValue))
        }

        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let url = URL(string: normalized) else {
            throw ClientError(kind: .invalidServerURL(rawValue))
        }

        return url
    }

    func generate(
        model: String,
        system: String?,
        prompt: String,
        temperature: Double,
        maxTokens: Int,
        contextWindow: Int? = nil
    ) async throws -> String {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("generate")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GenerateRequest(
            model: model,
            system: system,
            prompt: prompt,
            stream: false,
            options: .init(
                temperature: temperature,
                numPredict: maxTokens,
                numCtx: contextWindow
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw ClientError(kind: .requestFailed(httpResponse.statusCode, message))
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func version() async throws -> String {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("version")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw ClientError(kind: .requestFailed(httpResponse.statusCode, message))
        }

        let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
        return decoded.version
    }

    func listModels() async throws -> [String] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("tags")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw ClientError(kind: .requestFailed(httpResponse.statusCode, message))
        }

        let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
        return decoded.models.map(\.name).sorted()
    }
}

private struct GenerateRequest: Encodable {
    struct Options: Encodable {
        let temperature: Double
        let numPredict: Int
        let numCtx: Int?

        enum CodingKeys: String, CodingKey {
            case temperature
            case numPredict = "num_predict"
            case numCtx = "num_ctx"
        }
    }

    let model: String
    let system: String?
    let prompt: String
    let stream: Bool
    let options: Options
}

private struct GenerateResponse: Decodable {
    let response: String
}

private struct TagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}

private struct VersionResponse: Decodable {
    let version: String
}

private struct ErrorResponse: Decodable {
    let error: String
}
