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
        HStack {
            if let icon = icon {
                if let iconColor = iconColor {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 18))
                        .frame(width: 24)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            
            Spacer()
            
            content()
                .layoutPriority(1)
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
