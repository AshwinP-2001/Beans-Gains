import SwiftUI
import UserNotifications

struct CreatorFetchTestView: View {
    @State private var resultText = "Not tested yet."
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Zoho Creator & Notification Test")
                    .font(.title3.bold())

                Button {
                    resultText = CreatorTokenStore.tokenStatus
                } label: {
                    Label("Check Saved Token Status", systemImage: "key.horizontal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    CreatorTokenStore.clear()
                    resultText = "Tokens cleared! Now tap 'Connect to Zoho' below to re-authorize with the new write scope."
                } label: {
                    Label("Clear Tokens & Re-Authorize", systemImage: "trash.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    requestNotificationPermissions()
                } label: {
                    Label("1. Request Notification Permission", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await connectAndFetch() }
                } label: {
                    HStack {
                        if isWorking { ProgressView() }
                        Text(isWorking ? "Working…" : "2. Connect to Zoho & Fetch Records")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)

                Button {
                    Task { await runIntentManually() }
                } label: {
                    Label("3. Run Intent & Schedule 10m Reminders", systemImage: "bell.and.waves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await checkPendingNotifications() }
                } label: {
                    Label("4. Check Scheduled Notifications", systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await logSupplementNow() }
                } label: {
                    Label("5. Log Supplement to Zoho & Clear Reminders", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                ScrollView {
                    Text(resultText)
                        .font(.system(.footnote, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .navigationTitle("Test Console")
        }
    }

    @MainActor
    private func connectAndFetch() async {
        isWorking = true
        defer { isWorking = false }

        do {
            if CreatorTokenStore.accessToken() == nil {
                try await CreatorOAuthManager.shared.authorize()
            }
            let result = try await CreatorFetchClient.shared.fetchRecords()
            resultText = result
        } catch {
            resultText = "FAILED\n\(error.localizedDescription)"
        }
    }

    @MainActor
    private func runIntentManually() async {
        do {
            let intent = RefreshSupplementRemindersIntent()
            _ = try await intent.perform()
            
            resultText = "INTENT EXECUTED SUCCESSFULLY!\n\nChecked Zoho Creator and refreshed reminders."
        } catch {
            resultText = "INTENT FAILED:\n\(error.localizedDescription)"
        }
    }

    @MainActor
    private func logSupplementNow() async {
        do {
            try await CreatorAddClient.shared.addSupplementRecord()
            resultText = "SUCCESS!\nRecord posted to Zoho Creator and all pending reminders were cleared."
        } catch {
            resultText = "FAILED TO LOG:\n\(error.localizedDescription)"
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    resultText = "SUCCESS: Notification permissions granted!"
                } else {
                    resultText = "PERMISSION DENIED: Please enable notifications in iPhone Settings."
                }
                if let error = error {
                    resultText += "\nError: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func checkPendingNotifications() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        
        if pending.isEmpty {
            resultText = "PENDING NOTIFICATIONS: None currently scheduled."
        } else {
            let descriptions = pending.map { req in
                "- ID: \(req.identifier)"
            }.joined(separator: "\n")
            
            resultText = "PENDING NOTIFICATIONS (\(pending.count)):\n\n\(descriptions)"
        }
    }
}
