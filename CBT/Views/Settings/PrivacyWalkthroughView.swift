import SwiftUI

struct PrivacyWalkthroughView: View {
    @Environment(ThemeManager.self) private var themeManager

    var showsHeader: Bool = true

    private let items: [PrivacyWalkthroughItem] = [
        PrivacyWalkthroughItem(
            icon: "internaldrive.fill",
            title: "Stored on your device",
            message: "Your mood entries, journals, thought records, plans, and settings are saved locally first."
        ),
        PrivacyWalkthroughItem(
            icon: "icloud.fill",
            title: "Private iCloud sync",
            message: "When iCloud is available, Apple syncs your data through your private account so your devices can stay in step."
        ),
        PrivacyWalkthroughItem(
            icon: "lock.shield.fill",
            title: "App lock is optional",
            message: "You can add an app lock from Settings when you want an extra layer of privacy on this device."
        ),
        PrivacyWalkthroughItem(
            icon: "square.and.arrow.up.fill",
            title: "Export when you choose",
            message: "Backups and reports are created only when you ask for them, then shared or saved by you."
        ),
        PrivacyWalkthroughItem(
            icon: "trash.fill",
            title: "Delete what you need",
            message: "Reset options let you remove local records or delete synced iCloud data when you are done with it."
        ),
        PrivacyWalkthroughItem(
            icon: "eye.slash.fill",
            title: "No tracking",
            message: "The app does not run ads or send your private entries to us. Local retention insights stay on your device."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if showsHeader {
                    OnboardingHeader(
                        systemImage: "lock.shield.fill",
                        title: "Your data stays yours",
                        message: "CBT is designed for private self-reflection. Here is how storage, sync, export, deletion, and tracking work."
                    )
                }

                VStack(spacing: 10) {
                    ForEach(items) { item in
                        PrivacyWalkthroughRow(item: item, accent: themeManager.selectedColor)
                    }
                }

                Text("You can revisit privacy, sync, app lock, export, and reset controls from Settings at any time.")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }
}

private struct PrivacyWalkthroughItem: Identifiable {
    let icon: String
    let title: String
    let message: String

    var id: String { title }
}

private struct PrivacyWalkthroughRow: View {
    let item: PrivacyWalkthroughItem
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
