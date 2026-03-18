import SwiftUI

struct TopHeadlineView: View {
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: DSSpacing.xSmall) {
            Text(title)
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
        .frame(maxWidth: alignment == .center ? .infinity : nil)
        .padding(.top, DSSpacing.large)
        .padding(.bottom, DSSpacing.xSmall)
    }
}
