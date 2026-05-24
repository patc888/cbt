import SwiftUI

struct PagerLayout<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    VStack(spacing: 8) {
                        Text(title)
                            .font(DSTypography.pageTitle)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.primaryText)
                            .padding(.horizontal, 24)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.system(.body, design: .rounded))
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.horizontal, 32)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    content()
                        .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
