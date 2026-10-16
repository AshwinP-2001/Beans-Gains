import AppIntents
import UserNotifications

struct RefreshSupplementRemindersIntent: AppIntent {

    static let title: LocalizedStringResource =
        "Refresh Supplement Reminders"

    static let description = IntentDescription(
        "Checks Zoho Creator for today's supplement check-in and refreshes hourly reminders."
    )

    static let openAppWhenRun = false

    private let reminderPrefix = "supplement-reminder-"

    func perform() async throws -> some IntentResult {

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            return .result(
                dialog: "Notifications are not enabled. Check your iPhone notification settings."
            )
        }

        let creatorResult: String

        do {
            creatorResult = try await CreatorFetchClient.shared.fetchRecords()
        } catch {
            return .result(
                dialog: IntentDialog(
                    stringLiteral:
                        "Zoho Creator could not be checked. Existing reminders were left unchanged. Error: \(error.localizedDescription)"
                )
            )
        }

        let hasLoggedToday: Bool

        if creatorResult.hasPrefix("RECORD EXISTS") {
            hasLoggedToday = true
        } else if creatorResult.hasPrefix("NO RECORD PRESENT") {
            hasLoggedToday = false
        } else {
            return .result(
                dialog: "Zoho Creator returned an unexpected result. Existing reminders were left unchanged."
            )
        }

        guard let todayInterval = calendar.dateInterval(of: .day, for: now),
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: todayInterval.start) else {
            return .result(dialog: "Could not calculate the reminder dates.")
        }

        let startOfToday = todayInterval.start

        // Remove only this app's existing supplement reminders
        let pending = await center.pendingNotificationRequests()
        let oldReminderIDs = pending
            .filter { $0.identifier.hasPrefix(reminderPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: oldReminderIDs)

        var scheduledToday = 0
        var scheduledTomorrow = 0

        // Schedule remaining hourly reminders today only if Creator has no check-in for today
        if !hasLoggedToday {
            for hour in 0...23 {
                guard let fireDate = calendar.date(
                    bySettingHour: hour, minute: 0, second: 0, of: startOfToday
                ) else {
                    continue
                }

                if fireDate > now {
                    try await scheduleReminder(
                        for: fireDate,
                        hour: hour,
                        calendar: calendar,
                        center: center
                    )
                    scheduledToday += 1
                }
            }
        }

        // Always schedule tomorrow's hourly reminders
        for hour in 0...23 {
            guard let fireDate = calendar.date(
                bySettingHour: hour, minute: 0, second: 0, of: startOfTomorrow
            ) else {
                continue
            }

            try await scheduleReminder(
                for: fireDate,
                hour: hour,
                calendar: calendar,
                center: center
            )
            scheduledTomorrow += 1
        }

        let updatedPending = await center.pendingNotificationRequests()
        let reminderCount = updatedPending.filter {
            $0.identifier.hasPrefix(reminderPrefix)
        }.count

        let message: String

        if hasLoggedToday {
            message =
                "Zoho Creator: Today's check-in EXISTS. Today's reminders skipped. Tomorrow's reminders scheduled. Total pending: \(reminderCount)"
        } else {
            message =
                "Zoho Creator: NO CHECK-IN FOUND. Scheduled remaining today (\(scheduledToday)) & tomorrow (\(scheduledTomorrow)). Total pending: \(reminderCount)"
        }

        return .result(
            dialog: IntentDialog(stringLiteral: message)
        )
    }

    private func scheduleReminder(
        for fireDate: Date,
        hour: Int,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async throws {

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: hour)
        content.body = notificationMessage(for: hour)
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let year = calendar.component(.year, from: fireDate)
        let month = calendar.component(.month, from: fireDate)
        let day = calendar.component(.day, from: fireDate) // Corrected to use .day
        let actualHour = calendar.component(.hour, from: fireDate)

        let identifier =
            "\(reminderPrefix)\(year)-\(month)-\(day)-\(actualHour)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    private func notificationTitle(for hour: Int) -> String {
        if hour <= 8 {
            return "Good morning, King! 👑"
        } else if hour <= 22 {
            return "Busy day, King? 💪"
        } else {
            return "Final call, King! 👑"
        }
    }

    private func notificationMessage(for hour: Int) -> String {
        if hour <= 8 {
            return "Feeling fresh? Log your supplements, stay consistent, and have a great start to your day."
        } else if hour <= 22 {
            return "I know you've got work to do, but don't forget your supplement check-in. Take a moment for yourself."
        } else {
            return "You still have time, King! Log your supplements and finish the day strong."
        }
    }
}
