import AppKit

/// Fixed row heights for the dropdown. A ScrollView inside MenuBarExtra collapses to
/// zero without an explicit height, and measuring content height with GeometryReader
/// leaves the panel blank on macOS 26, so scroll heights are calculated from these.
enum MenuMetrics {
    static let serviceRowHeight: CGFloat = 36
    static let topicRowHeight: CGFloat = 44
    static let componentRowHeight: CGFloat = 18
    static let advisoryRowHeight: CGFloat = 36
    static let linkRowHeight: CGFloat = 24
    static let sectionHeaderHeight: CGFloat = 36
    static let dividerHeight: CGFloat = 1
    static let listVerticalPadding: CGFloat = 8

    /// Upper bound for one expanded list; longer lists scroll inside the row.
    static let maxExpandedListHeight: CGFloat = 320

    /// Space taken by the pinned header, footer, update banner and window margins.
    private static let reservedPanelHeight: CGFloat = 200

    /// Height of an expanded list of `rowCount` rows.
    static func expandedListHeight(rowCount: Int, rowHeight: CGFloat) -> CGFloat {
        min(CGFloat(rowCount) * rowHeight, maxExpandedListHeight)
    }

    /// Height available to the scrolling part of the panel, so the panel always fits on
    /// screen and every row stays reachable.
    static var maxScrollHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - reservedPanelHeight
    }
}
