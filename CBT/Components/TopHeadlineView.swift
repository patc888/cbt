import SwiftUI

struct TopHeadlineView: View {
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: alignment == .center ? .infinity : nil)
        .padding(.top, 20)
        .padding(.bottom, 0)
    }
}
