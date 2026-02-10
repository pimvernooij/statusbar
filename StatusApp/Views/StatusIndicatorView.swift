import SwiftUI

struct StatusIndicatorView: View {
    let status: OverallStatus
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: StatusColor.sfSymbolName(for: status))
            .foregroundStyle(StatusColor.color(for: status))
            .font(.system(size: size))
    }
}
