import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TimeAboutSettingsView: View {
    let onReset: () -> Void
    @State private var showingShareSheet = false

    private var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        TimeSettingsSection(title: "About") {
            TimeSettingsRow(icon: "info.circle", iconColor: Theme.primaryPurple, title: "Version") {
                Text(appVersionDisplay)
                    .timeSettingsValueStyle()
            }
            
            Button(action: {
                HapticManager.shared.lightImpact()
                showingShareSheet = true
            }) {
                TimeSettingsRow(icon: "square.and.arrow.up", iconColor: Theme.primaryPurple, title: "Share this App") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingShareSheet) {
                TimeShareAppView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(Theme.cornerRadiusXLarge)
                    .presentationBackground { Theme.backgroundColor }
            }

            aboutLinkRow(
                icon: "star.bubble",
                title: "Review this App",
                urlString: "https://apps.apple.com/app/id0000000000?action=write-review"
            )
            aboutLinkRow(
                icon: "questionmark.circle",
                title: "Help Center",
                urlString: "https://xeo.com/time/support.html"
            )
            aboutLinkRow(
                icon: "lock.shield",
                title: "Privacy Policy",
                urlString: "https://xeo.com/time/privacy-policy.html"
            )
            aboutLinkRow(
                icon: "doc.text",
                title: "Terms of Use",
                urlString: "https://xeo.com/time/terms.html"
            )

            Button(action: {
                HapticManager.shared.lightImpact()
            }) {
                TimeSettingsRow(icon: "keyboard", iconColor: Theme.primaryPurple, title: "Keyboard Shortcuts") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive, action: onReset) {
                HStack {
                    Image(systemName: "trash")
                    Text("Reset All Data")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func aboutLinkRow(icon: String, title: String, urlString: String) -> some View {
        Button(action: { openURL(urlString) }) {
            TimeSettingsRow(icon: icon, iconColor: Theme.primaryPurple, title: title) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        HapticManager.shared.lightImpact()
#if os(iOS)
        UIApplication.shared.open(url)
#elseif os(macOS)
        NSWorkspace.shared.open(url)
#endif
    }
}

private struct TimeShareAppView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Time")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            Text("Invite someone to plan their day with Time.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            ShareLink(item: URL(string: "https://xeo.com/time")!) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.backgroundColor)
    }
}
