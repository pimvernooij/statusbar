import AppKit
import SwiftUI

enum MenuBarIconRenderer {
    static func icon(for status: OverallStatus) -> NSImage {
        let symbolName = StatusColor.sfSymbolName(for: status)
        let color = NSColor(StatusColor.color(for: status))

        let config = NSImage.SymbolConfiguration(
            pointSize: 14,
            weight: .regular
        )
        .applying(.init(paletteColors: [color]))

        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: StatusColor.label(for: status))?
            .withSymbolConfiguration(config) else {
            let fallback = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Unknown")!
            fallback.isTemplate = true
            return fallback
        }

        image.isTemplate = false
        return image
    }
}
