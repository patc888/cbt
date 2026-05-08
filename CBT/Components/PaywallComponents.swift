import SwiftUI

struct ProUpgradeCard: View {
    var title: String
    var subtitle: String
    var ctaTitle: String
    var footnote: String?
    var isFullColorTheme: Bool = true
    var action: () -> Void
    var isLoading = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    private var primaryColor: Color {
        themeManager.selectedColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                AppIconView(size: 50)
                    .shadow(color: colorScheme == .dark ? primaryColor.opacity(0.3) : .clear, radius: colorScheme == .dark ? 5 : 0, x: 0, y: colorScheme == .dark ? 3 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(DSTheme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(DSTheme.secondaryText)
                }
            }

            Button(action: {
                HapticManager.shared.mediumImpact()
                action()
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
                .background(primaryColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .premiumPressEffect()
            .disabled(isLoading)

            if let footnote {
                Text(footnote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DSTheme.secondaryText.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, -4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.lightImpact()
            action()
        }
    }
}
