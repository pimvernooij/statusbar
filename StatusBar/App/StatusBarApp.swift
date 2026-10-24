import SwiftUI
import UserNotifications

@main
struct StatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var pollingService = StatusPollingService()
    @State private var advisoryService = AdvisoryPollingService()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(pollingService: pollingService, advisoryService: advisoryService)
        } label: {
            let status = pollingService.worstStatus
            Image(systemName: StatusColor.sfSymbolName(for: status))
                .symbolRenderingMode(.palette)
                .foregroundStyle(StatusColor.color(for: status))
        }
        .menuBarExtraStyle(.window)

        Window("", id: "settings") {
            SettingsView(pollingService: pollingService, advisoryService: advisoryService)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Upgrade from LSUIElement (.prohibited) to .accessory at launch
        // so the app can take focus when settings opens, without showing a dock icon
        NSApp.setActivationPolicy(.accessory)

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Open the advisory (or status page) linked to a clicked notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let urlString = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlString)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}
