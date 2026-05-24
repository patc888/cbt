import SwiftUI

struct SupportiveEmptyStateView: View {
    @Environment(ThemeManager.self) private var themeManager

    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let actionSystemImage: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 72, height: 72)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage ?? "arrow.right.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .frame(maxWidth: 320)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}
