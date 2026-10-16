import Foundation

 enum GeminiError: LocalizedError {
    case missingAPIKey
    case badURL
    case server(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Add your key in GeminiAIService.swift."
        case .badURL:
            return "Invalid Gemini endpoint URL."
        case .server(let status, let message):
            return "Gemini returned HTTP \(status): \(message)"
        case .emptyResponse:
            return "Gemini returned no text. Please try again."
        }
    }
}

struct GeminiAIService {
    static let shared = GeminiAIService()
    private init() {}

    // Add your replacement Gemini API key here. Do not commit this file publicly.
    // Rotate any key that was previously shared or exposed.
    private let apiKey = "AIzaSyC02rzlNbJcXZhJRADHnp-_HLsdZQB84Y8"
    private let model = "gemini-2.5-flash"

    private var workingURL: URL? {
        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components?.url
    }

    func analyzeWorkouts(
        workoutHistoryJSON: String,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        gender: String
    ) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key != "PASTE_YOUR_NEW_GEMINI_API_KEY_HERE" else {
            throw GeminiError.missingAPIKey
        }
        guard let url = workingURL else { throw GeminiError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let promptText = """
        You are a knowledgeable strength and conditioning coach reviewing the user's logged workouts from the last 30 days.

        Saved profile:
        Age: \(age) years
        Gender: \(gender)
        Height: \(heightCm) cm
        Body weight: \(weightKg) kg

        Workout logs (JSON; sessions are dated and each set includes exercise, muscle group, weight, and reps):
        \(workoutHistoryJSON)

        Analyze the full 30-day history, not just the most recent session. When assessing progressive overload, compare the same exercise across different dates and compare load and reps; only claim progress when the logs support the comparison. Do not treat different exercise names as the same movement unless clearly equivalent.

        Write a concise report with EXACTLY 4 short bullet points, no introduction or conclusion. Keep each bullet to at most 2 sentences and the whole report under 180 words.
        Cover these topics in order:
        1. Progressive overload trends for repeated exercises, including load/reps comparisons where available.
        2. Training frequency, volume trends, and muscle groups trained over the 30-day period.
        3. One specific actionable tip for the next relevant Push, Pull, or Legs session.
        4. Consistency or recovery considerations only if the data supports them.

        Use the profile as context, not as a basis for unsupported assumptions or medical advice. Do not invent sessions, exercises, sets, progress, or recovery data. If there is too little repeated data to assess progression, say so briefly.
        Return plain text with four bullets. Do not use Markdown bold markers, headings, or asterisks for formatting. Do not include a partial sentence; finish every bullet completely.
        """

        let payload: [String: Any] = [
            "contents": [["parts": [["text": promptText]]]],
            "generationConfig": [
                "temperature": 0.5,
                "maxOutputTokens": 4096
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw GeminiError.server(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.emptyResponse
        }

        if let promptFeedback = json["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            throw GeminiError.server(status: http.statusCode, message: "Request blocked: \(blockReason)")
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let candidate = candidates.first,
              let content = candidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.emptyResponse
        }

        let result = parts.compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw GeminiError.emptyResponse }

        // Detect the common cause of an abruptly cut-off answer.
        let finishReason = candidate["finishReason"] as? String
        if finishReason == "MAX_TOKENS" {
            return result + "\n\n_Report may be incomplete: Gemini reached its output-token limit._"
        }
        return result
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

/****
Home Screen Flow

Home Screen
  - HomeScreenViewController.swift
  - CustomViewController.swift
  - HomeScreenPresenter.swift
  - HomeScreenInteractor.swift
  - HomeScreenRouter.swift
 
 
 SwfitUI
*/
