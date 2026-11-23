import AppKit
import UserNotifications

/// Tells the user how a take ended, with buttons to reveal it in Finder or play it.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let revealAction = "reveal", playAction = "play", takeCategory = "take"
    /// Notifications need an app bundle; the bare executable (as run by `swift run`) has none.
    private let center: UNUserNotificationCenter? = Bundle.main.bundleIdentifier == nil ? nil : .current()

    override init() {
        super.init()
        guard let center else { return }
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(
            identifier: takeCategory,
            actions: [UNNotificationAction(identifier: revealAction, title: "Reveal in Finder"),
                      UNNotificationAction(identifier: playAction, title: "Play")],
            intentIdentifiers: [])])
    }

    /// Asks macOS once for permission to show notifications.
    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// - Parameter file: what the Reveal and Play buttons act on, if anything was kept.
    func show(title: String, body: String, file: URL?) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let file {
            content.categoryIdentifier = takeCategory
            content.userInfo = ["path": file.path]
        }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard let path = response.notification.request.content.userInfo["path"] as? String else { return }
        let file = URL(fileURLWithPath: path)
        DispatchQueue.main.async {
            if response.actionIdentifier == self.playAction {
                NSWorkspace.shared.open(file)
            } else {
                // The Reveal button, or a click on the notification itself.
                NSWorkspace.shared.activateFileViewerSelecting([file])
            }
        }
    }
}
