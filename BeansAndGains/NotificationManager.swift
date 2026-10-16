
import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let reminderPrefix = "supplement-reminder-"

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional {
                return true
            }

            if settings.authorizationStatus == .denied {
                print("Notifications are disabled in Settings.")
                return false
            }

            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            print("Notification permission granted: \(granted)")
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Test Notification

    func sendTestNotification() async {
        guard await requestPermission() else {
            print("Test notification skipped: permission not granted.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Test Reminder 👑"
        content.body = "Bro, your supplement reminder is working! 💪"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "supplement-test-notification",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("Test notification scheduled for 5 seconds.")
        } catch {
            print("Failed to schedule test notification: \(error)")
        }
    }

    // MARK: - Check Today's Log

    func hasLoggedToday(
        in modelContext: ModelContext
    ) throws -> Bool {
        let calendar = Calendar.current

        guard let interval = calendar.dateInterval(
            of: .day,
            for: .now
        ) else {
            return false
        }

        let start = interval.start
        let end = interval.end

        let descriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { log in
                log.logDate >= start && log.logDate < end
            }
        )

        return try !modelContext.fetch(descriptor).isEmpty
    }

    // MARK: - Refresh Today and Tomorrow

    func refreshReminders(
        using modelContext: ModelContext
    ) async {
        guard await requestPermission() else {
            print("Reminder scheduling skipped: no permission.")
            return
        }

        let alreadyLoggedToday: Bool

        do {
            alreadyLoggedToday = try hasLoggedToday(
                in: modelContext
            )
        } catch {
            print("Could not check today's logs: \(error)")
            return
        }

        // Clear old reminders before building the new schedule.
        await cancelPendingReminders()

        let calendar = Calendar.current
        let now = Date()

        guard let today = calendar.dateInterval(
            of: .day,
            for: now
        )?.start,
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) else {
            print("Could not calculate reminder dates.")
            return
        }

        print("========== REMINDER REFRESH ==========")
        print("Current local time: \(formatLocalDate(now))")
        print("Today's check-in exists: \(alreadyLoggedToday)")

        // Schedule the remaining hours of today only if
        // today's check-in has not been completed.
        if !alreadyLoggedToday {
            await scheduleReminders(
                for: today,
                startingAfter: now,
                calendar: calendar
            )
        } else {
            print("Today's reminders skipped: check-in exists.")
        }

        // Always schedule tomorrow's 24 hourly reminders.
        await scheduleReminders(
            for: tomorrow,
            startingAfter: nil,
            calendar: calendar
        )

        let pending = await center.pendingNotificationRequests()
        let hourlyCount = pending.filter {
            $0.identifier.hasPrefix(reminderPrefix)
        }.count

        print("Hourly reminders currently pending: \(hourlyCount)")
        print("======================================")
    }

    // MARK: - Schedule a Day

    private func scheduleReminders(
        for day: Date,
        startingAfter date: Date?,
        calendar: Calendar
    ) async {
        for hour in 0...23 {
            guard let fireDate = calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: day
            ) else {
                continue
            }

            // For today, skip hours that have already passed.
            if let date, fireDate <= date {
                continue
            }

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

            let identifier = reminderIdentifier(
                for: fireDate,
                calendar: calendar
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                print("Scheduled local time: \(formatLocalDate(fireDate))")
                print("Reminder ID: \(identifier)")
            } catch {
                print("Failed to schedule \(identifier): \(error)")
            }
        }
    }

    // MARK: - Notification Messages

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
            return """
            Feeling fresh? Log your supplements, stay consistent, \
            and have a great start to your day.
            """
        } else if hour <= 22 {
            return """
            I know you've got work to do, but don't forget your \
            supplement check-in. Take a moment for yourself.
            """
        } else {
            return """
            You still have time, King! Log your supplements \
            and finish the day strong.
            """
        }
    }

    // MARK: - Cancel All Hourly Reminders

    func cancelPendingReminders() async {
        let requests = await center.pendingNotificationRequests()

        let identifiers = requests
            .filter { $0.identifier.hasPrefix(reminderPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )

        print("Cancelled \(identifiers.count) pending hourly reminders.")
    }

    // MARK: - Cancel Reminders for One Day

    func cancelReminders(for date: Date) async {
        let calendar = Calendar.current
        let requests = await center.pendingNotificationRequests()

        let identifiers = requests.compactMap { request -> String? in
            guard request.identifier.hasPrefix(reminderPrefix),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let triggerDate = calendar.date(from: trigger.dateComponents),
                  calendar.isDate(triggerDate, inSameDayAs: date)
            else {
                return nil
            }

            return request.identifier
        }

        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )

        print("Cancelled \(identifiers.count) reminders for \(calendar.startOfDay(for: date)).")
    }

    // MARK: - Date Formatting

    private func formatLocalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss a z"
        return formatter.string(from: date)
    }

    private func reminderIdentifier(
        for date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: date
        )

        return "\(reminderPrefix)" +
            "\(components.year ?? 0)-" +
            "\(components.month ?? 0)-" +
            "\(components.day ?? 0)-" +
            "\(components.hour ?? 0)"
    }
}

