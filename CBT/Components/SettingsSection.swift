import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 16) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
            }
            
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .cardStyle()
    }
}
