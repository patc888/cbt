import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    @State private var showingLegalInfo = false
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        SettingsSection(title: String(localized: "About")) {
            Button(action: {
                openURL("https://xeo.com/CBT/support.html")
            }) {
                SettingsRow(icon: "questionmark.circle", iconColor: themeManager.selectedColor, title: String(localized: "Help Center")) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                HapticManager.shared.lightImpact()
                showingLegalInfo = true
            }) {
                SettingsRow(icon: "doc.text.magnifyingglass", iconColor: themeManager.selectedColor, title: String(localized: "Legal & Info")) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: DataResetOptionsView()) {
                HStack {
                    Image(systemName: "trash")
                    Text(String(localized: "Reset Device Data"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.errorRed)
            }
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle())

            Divider()
                .padding(.leading, 16)

            NavigationLink(destination: DataResetOptionsView()) {
                HStack {
                    Image(systemName: "person.badge.minus")
                    Text(String(localized: "Delete Account & Data"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.errorRed)
            }
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingLegalInfo) {
            LegalView()
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            HapticManager.shared.lightImpact()
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

private struct LegalInfoSheet: View {
    let openURL: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Theme.tertiaryText.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Header
            ZStack {
                Text(String(localized: "Legal & Info"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Button(String(localized: "Done")) {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.selectedColor)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 20) {
                        // Conspicuous Medical Disclaimer
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(String(localized: "Medical Disclaimer"))
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                            }

                            Text(String(localized: "This app provides cognitive behavioral therapy tools for educational purposes and is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition."))
                                .font(.system(size: 13, design: .rounded))
                                .lineSpacing(3)
                                .foregroundStyle(Theme.primaryText)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "In Case of Emergency:"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.errorRed)
                                
                                Text(String(localized: "If you are in a crisis or experiencing a medical emergency, please call your local emergency services (911 in the US) or go to the nearest emergency room immediately."))
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                            }
                            .padding()
                            .background(Theme.errorRed.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusMedium)

                        VStack(spacing: 0) {
                            Button {
                                openURL("https://xeo.com/CBT/privacy-policy.html")
                            } label: {
                                SettingsRow(icon: "lock.shield", iconColor: themeManager.selectedColor, title: String(localized: "Privacy Policy")) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, 52)

                            Button {
                                openURL("https://xeo.com/CBT/terms.html")
                            } label: {
                                SettingsRow(icon: "doc.text", iconColor: themeManager.selectedColor, title: String(localized: "Terms of Use")) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusMedium)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.secondaryBackground)
    }
}
