import SwiftUI

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.7"
        return "Version \(version)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        LegalSection(title: "Privacy Policy") {
                            Text("Your privacy is our priority. This app is designed to keep your mental health data private and secure.")
                                .font(.system(.body, design: .rounded))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                LegalBullet(text: "All entries are stored locally on your device.")
                                LegalBullet(text: "We do not have access to your moods, thoughts, or journal entries.")
                                LegalBullet(text: "No personal data is shared with third parties.")
                            }
                        }

                        LegalSection(title: "Terms of Service") {
                            Text("By using this app, you agree to the following terms:")
                                .font(.system(.body, design: .rounded))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                LegalBullet(text: "This app is a self-help tool and does not replace professional medical advice or therapy.")
                                LegalBullet(text: "If you are in a crisis, please contact emergency services immediately.")
                                LegalBullet(text: "Data safety is dependent on your device security.")
                            }
                        }
                        
                        Text(appVersionText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.top, 16)
                    }
                    .padding(20)
                    .responsiveMaxWidth()
                }
            }
            .navigationTitle("Legal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            
            content()
        }
    }
}

private struct LegalBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(.body, design: .rounded).weight(.bold))
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
