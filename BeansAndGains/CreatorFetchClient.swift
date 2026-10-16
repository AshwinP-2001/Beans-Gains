import Foundation

final class CreatorFetchClient {

    static let shared = CreatorFetchClient()

    private init() {}

    func fetchRecords() async throws -> String {
        return try await fetchRecordsWithRetry(isRetry: false)
    }

    private func fetchRecordsWithRetry(isRetry: Bool) async throws -> String {
        let urlString =
            "https://www.zohoapis.com/creator/v2.1/data/" +
            "ashwinpaulrajt0_zohotest/supplement-tracker/report/" +
            "Daily_Supplement_Report" +
            "?field_config=custom&fields=Date_Time&max_records=200"

        guard let url = URL(string: urlString) else {
            throw FetchError.invalidURL
        }

        guard let accessToken = CreatorTokenStore.accessToken() else {
            throw FetchError.missingToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "Zoho-oauthtoken \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        // Automatically refresh token on 401 Unauthorized
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                try await CreatorOAuthManager.shared.refreshAccessToken()
                return try await fetchRecordsWithRetry(isRetry: true)
            } catch {
                throw FetchError.apiError(
                    "Session expired and token refresh failed: \(error.localizedDescription)"
                )
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(
                data: data,
                encoding: .utf8
            ) ?? "No response body"

            throw FetchError.apiError(
                "HTTP \(httpResponse.statusCode)\n\(body)"
            )
        }

        let decoded = try JSONDecoder().decode(
            CreatorReportResponse.self,
            from: data
        )

        guard decoded.code == 3000 else {
            throw FetchError.apiError(
                "Zoho Creator returned code \(decoded.code)"
            )
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd-MMM-yyyy HH:mm:ss"

        let matchingRecords = decoded.data.filter { record in
            guard let recordDate = formatter.date(
                from: record.dateTime
            ) else {
                return false
            }

            return calendar.isDate(
                recordDate,
                inSameDayAs: today
            )
        }

        let todayFormatter = DateFormatter()
        todayFormatter.locale = Locale(identifier: "en_US_POSIX")
        todayFormatter.timeZone = TimeZone.current
        todayFormatter.dateFormat = "dd-MMM-yyyy"

        let todayText = todayFormatter.string(from: today)

        if let record = matchingRecords.first {
            return """
            RECORD EXISTS

            Date checked: \(todayText)
            Matching records: \(matchingRecords.count)

            Date_Time: \(record.dateTime)
            Record ID: \(record.id)
            """
        }

        return """
        NO RECORD PRESENT

        Date checked: \(todayText)
        Records scanned: \(decoded.data.count)
        """
    }
}

private struct CreatorReportResponse: Decodable {
    let code: Int
    let data: [CreatorRecord]
}

private struct CreatorRecord: Decodable {
    let dateTime: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case dateTime = "Date_Time"
        case id = "ID"
    }
}

private enum FetchError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Zoho Creator API URL."
        case .missingToken: return "No access token found. Please connect to Zoho again."
        case .invalidResponse: return "Invalid response received from Zoho Creator."
        case .apiError(let message): return message
        }
    }
}
