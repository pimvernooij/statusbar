import AppKit
import SwiftUI

/// Sizes the MenuBarExtra panel to `height`, keeping its top edge under the menu bar.
/// The panel doesn't reliably follow SwiftUI's size in builds made with the macOS 15
/// SDK, which leaves the content clipped or surrounded by empty space.
struct PanelHeightSetter: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> PanelHeightView {
        PanelHeightView()
    }

    func updateNSView(_ nsView: PanelHeightView, context: Context) {
        nsView.targetHeight = height
    }
}

final class PanelHeightView: NSView {
    var targetHeight: CGFloat = 0 {
        didSet { scheduleResize() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleResize()
    }

    /// Deferred because the window can't be resized during a SwiftUI update.
    private func scheduleResize() {
        DispatchQueue.main.async { [weak self] in
            self?.resizeWindow()
        }
    }

    private func resizeWindow() {
        guard let window, targetHeight > 0 else { return }
        var frame = window.frame
        guard abs(frame.height - targetHeight) > 0.5 else { return }
        frame.origin.y = frame.maxY - targetHeight
        frame.size.height = targetHeight
        window.setFrame(frame, display: true)
    }
}
