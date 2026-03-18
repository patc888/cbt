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
        DSListRow(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            content()
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(subtitle != nil ? ", \(subtitle!)" : "")")
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
