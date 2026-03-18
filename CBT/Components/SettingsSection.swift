import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 10) {
            if !title.isEmpty {
                DSSectionHeader(title: title)
            }
            
            content()
        }
        .padding(.horizontal, DSSpacing.large)
        .padding(.vertical, DSSpacing.large)
        .cardStyle()
    }
}
