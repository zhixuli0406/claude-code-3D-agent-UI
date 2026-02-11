import Foundation
import UserNotifications

/// Manages macOS native notifications for task events
@MainActor
class NotificationManager: ObservableObject {
    @Published var notifyOnCompletion: Bool {
        didSet { UserDefaults.standard.set(notifyOnCompletion, forKey: "notifyOnCompletion") }
    }
    @Published var notifyOnError: Bool {
        didSet { UserDefaults.standard.set(notifyOnError, forKey: "notifyOnError") }
    }
    @Published var notifyOnPermission: Bool {
        didSet { UserDefaults.standard.set(notifyOnPermission, forKey: "notifyOnPermission") }
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "notificationsEnabled") }
    }

    private var isAuthorized = false

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.notifyOnCompletion = UserDefaults.standard.object(forKey: "notifyOnCompletion") as? Bool ?? true
        self.notifyOnError = UserDefaults.standard.object(forKey: "notifyOnError") as? Bool ?? true
        self.notifyOnPermission = UserDefaults.standard.object(forKey: "notifyOnPermission") as? Bool ?? true
        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
            }
        }
    }

    func notifyTaskCompleted(taskTitle: String, agentName: String) {
        guard isEnabled, isAuthorized, notifyOnCompletion else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Completed"
        content.body = "\(agentName) finished: \(taskTitle)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func notifyTaskFailed(taskTitle: String, agentName: String) {
        guard isEnabled, isAuthorized, notifyOnError else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Failed"
        content.body = "\(agentName) encountered an error: \(taskTitle)"
        content.sound = UNNotificationSound.defaultCritical

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func notifyPermissionRequest(agentName: String, tool: String) {
        guard isEnabled, isAuthorized, notifyOnPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "Permission Required"
        content.body = "\(agentName) needs approval to use: \(tool)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
