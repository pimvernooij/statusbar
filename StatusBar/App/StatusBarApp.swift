import SwiftUI
import UserNotifications

@main
struct StatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var pollingService = StatusPollingService()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(pollingService: pollingService)
        } label: {
            let status = pollingService.worstStatus
            Image(systemName: StatusColor.sfSymbolName(for: status))
                .symbolRenderingMode(.palette)
                .foregroundStyle(StatusColor.color(for: status))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(pollingService: pollingService)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Upgrade from LSUIElement (.prohibited) to .accessory at launch
        // so the app can take focus when settings opens, without showing a dock icon
        NSApp.setActivationPolicy(.accessory)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
