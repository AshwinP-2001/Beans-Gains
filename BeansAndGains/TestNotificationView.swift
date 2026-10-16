import SwiftUI
import UserNotifications

struct TestNotificationView: View {
    @State private var statusMessage: String = "Tap button to test notification"
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Beans & Gains")
                .font(.largeTitle)
                .bold()
            
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                triggerTestNotification()
            }) {
                Label("Trigger Test Notification", systemImage: "paperplane.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func triggerTestNotification() {
        let center = UNUserNotificationCenter.current()
        
        // 1. Request notification permissions
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.statusMessage = "Notification scheduled! Lock your phone or go home within 3 seconds..."
                    self.scheduleNotification(center: center)
                } else if let error = error {
                    self.statusMessage = "Error requesting permission: \(error.localizedDescription)"
                } else {
                    self.statusMessage = "Notification permissions denied in Settings."
                }
            }
        }
    }
    
    private func scheduleNotification(center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Good morning, King! 👑"
        content.body = "Feeling fresh? Log your supplements, stay consistent, and have a great start to your day."
        content.sound = .default
        
        // Trigger after 3 seconds so you can switch off the screen or swipe home to see the banner
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "TestNotification_\(UUID().uuidString)", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to schedule: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    TestNotificationView()
}
