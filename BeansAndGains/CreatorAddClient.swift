import Foundation
import UserNotifications

struct SupplementCheckInModel {
    var logDate: Date = Date()
    var dailyCreatine: Bool = false
    var zincIntake: Bool = false
    var vitaminD: Bool = false
    var calciumIntake: Bool = false
    var multivitaminIntake: Bool = false
    var vitaminCIntake: Bool = false
    var vitaminBIntake: Bool = false
    var fishOilIntake: Bool = false
    var alcoholToday: Bool = false
    var howMuchAlcohol: String = ""
    var workoutRoutine: String = ""
    var dailyFeeling: String = ""
    var magnesiumIntake: Bool = false
    var biotinIntake: Bool = false
    var cigarette: Bool = false
    var howManyCigarettes: String = ""
    var medications: [MedicationEntry] = []
}

final class CreatorAddClient {

    static let shared = CreatorAddClient()

    private init() {}

    func addSupplementRecord(entry: SupplementCheckInModel = SupplementCheckInModel()) async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd-MMM-yyyy HH:mm:ss"
        let dateTimeString = formatter.string(from: entry.logDate)

        let urlString =
            "https://www.zohoapis.com/creator/v2.1/data/" +
            "\(CreatorConfiguration.accountOwner)/" +
            "\(CreatorConfiguration.appLinkName)/form/" +
            "\(CreatorConfiguration.formLinkName)"

        guard let url = URL(string: urlString) else {
            throw AddError.invalidURL
        }

        guard let accessToken = CreatorTokenStore.accessToken() else {
            throw AddError.missingToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Zoho-oauthtoken \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var recordData: [String: Any] = [
            "Date_Time": dateTimeString,
            "Daily_Creatine": entry.dailyCreatine ? "Yes" : "No",
            "Calcium_Intake": entry.calciumIntake ? "Yes" : "No",
            "Multivitamin_Intake": entry.multivitaminIntake ? "Yes" : "No",
            "Vitamin_C_Intake": entry.vitaminCIntake ? "Yes" : "No",
            "Vitamin_B_Intake": entry.vitaminBIntake ? "Yes" : "No",
            "Fish_Oil_Intake": entry.fishOilIntake ? "Yes" : "No",
            "Alcohol_Today": entry.alcoholToday ? "Yes" : "No",
            "Workout_Routine": entry.workoutRoutine,
            "How_are_you_feeling_today": entry.dailyFeeling
        ]

        recordData["Zinc_Intake"] = entry.zincIntake ? "Yes" : "No"
        recordData["Vitamin_D"] = entry.vitaminD ? "Yes" : "No"
        recordData["Magnesium_Intake"] = entry.magnesiumIntake ? "Yes" : "No"
        recordData["Biotin_Intake"] = entry.biotinIntake ? "Yes" : "No"
        recordData["Cigarette"] = entry.cigarette ? "Yes" : "No"

        if entry.cigarette, !entry.howManyCigarettes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recordData["How_many_Cigarettes"] = entry.howManyCigarettes
        }

        let medicationRows = entry.medications.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if !medicationRows.isEmpty {
            recordData["Medication"] = medicationRows.map { medication in
                var row: [String: Any] = [
                    "Name_of_the_medicine": medication.name,
                    "Intake_time": medication.intakeTime
                ]
                let trimmedDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                if let dosage = Double(trimmedDosage), dosage.isFinite {
                    row["Dosage"] = dosage
                }
                return row
            }
        }

        if entry.alcoholToday, let amount = Double(entry.howMuchAlcohol) {
            recordData["How_Much_Alcohol"] = amount
        }

        let payload: [String: Any] = [
            "data": [recordData]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AddError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AddError.apiError("Authorization expired (HTTP 401). Please go to Settings and re-authorize with Zoho.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No error body"
            throw AddError.apiError("HTTP \(httpResponse.statusCode)\n\(body)")
        }

        await cancelSupplementReminders()
    }

    private func cancelSupplementReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        
        let reminderPrefix = "supplement-reminder-"
        let oldReminderIDs = pending
            .filter { $0.identifier.hasPrefix(reminderPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: oldReminderIDs)
    }
}

private enum AddError: LocalizedError {
    case invalidURL
    case missingToken
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Zoho Creator API URL."
        case .missingToken: return "No access token found. Please go to Settings and connect to Zoho."
        case .invalidResponse: return "Invalid response received from Zoho Creator."
        case .apiError(let message): return message
        }
    }
}
