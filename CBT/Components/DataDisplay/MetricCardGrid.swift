import SwiftUI

struct MetricCardGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ViewBuilder let content: () -> Content

    private var gridSpacing: CGFloat {
        horizontalSizeClass == .regular ? 16 : 12
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
