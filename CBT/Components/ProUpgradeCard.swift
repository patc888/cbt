import SwiftUI

struct ProUpgradeCard: View {
    var title: String
    var subtitle: String
    var ctaTitle: String
    var footnote: String?
    var isFullColorTheme: Bool = true
    var action: () -> Void
    var ctaAction: (() -> Void)? = nil 
    var isLoading: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    
    private var primaryColor: Color {
        themeManager.selectedColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                AppIconView(size: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            
            Button(action: {
                HapticManager.shared.mediumImpact()
                if let ctaAction = ctaAction {
                    ctaAction()
                } else {
                    action()
                }
            }) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .background(themeManager.selectedColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            
            if let footnote = footnote {
                Text(footnote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, -4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.lightImpact()
            action()
        }
    }
}
