import SwiftUI

@main
struct StatusAppApp: App {
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
