import SwiftUI

struct SettingsRow<Content: View>: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let subtitle: String?
    let content: () -> Content

    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(subtitle != nil ? ", \(subtitle ?? "")" : "")")
    }

    private var leadingContent: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon = icon {
                if let iconColor = iconColor {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 18))
                        .frame(width: 24)
                        .padding(.top, 1)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 10) {
            leadingContent
                .layoutPriority(1)

            content()
                .layoutPriority(0)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            leadingContent

            HStack {
                Spacer(minLength: 0)
                content()
            }
        }
    }
}

extension SettingsRow where Content == EmptyView {
    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = { EmptyView() }
    }
}
