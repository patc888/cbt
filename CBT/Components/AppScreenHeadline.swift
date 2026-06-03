import SwiftUI

struct TopHeadlineView<Leading: View, Trailing: View>: View {
    let title: String
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                HStack {
                    leading
                    Spacer()
                }

                Text(title)
                    .font(DSTypography.headerTitle)
                    .foregroundStyle(DSTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 112)

                HStack {
                    Spacer()
                    trailing
                }
            }
            .frame(minHeight: 44)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }
}

struct AppScreenHeadline: View {
    let title: String

    var body: some View {
        TopHeadlineView(
            title: title,
            leading: { StreakToolbarButton() }
        )
    }
}

extension TopHeadlineView where Leading == EmptyView, Trailing == EmptyView {
    init(title: String) {
        self.init(title: title, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

extension TopHeadlineView where Leading == EmptyView {
    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, leading: { EmptyView() }, trailing: trailing)
    }
}

extension TopHeadlineView where Trailing == EmptyView {
    init(title: String, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, leading: leading, trailing: { EmptyView() })
    }
}
