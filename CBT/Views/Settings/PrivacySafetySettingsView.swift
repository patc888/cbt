import SwiftData
import SwiftUI

struct PrivacySafetySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(CloudKitSyncMonitor.self) private var syncStatusMonitor
    @AppStorage(AppConfiguration.cloudKitEnabledKey) private var isCloudKitStoreEnabled = false
    @AppStorage(AppConfiguration.cloudKitFailureReasonKey) private var cloudKitFailureReason = ""
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    AppScreenHeadline(title: String(localized: "Privacy & Safety"))
                        .padding(.horizontal, 16)

                    if viewModel.isInitialized {
                        content
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .responsiveMaxWidth(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.initialize(with: modelContext)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            privacyExplanationSection

            SecuritySettingsView(
                appLockEnabled: viewModel.appLockEnabled,
                discreetModeEnabled: viewModel.discreetModeEnabled,
                onUpdateAppLock: { enabled in
                    viewModel.updateAppLock(enabled)
                },
                onUpdateDiscreetMode: { enabled in
                    viewModel.updateDiscreetMode(enabled)
                }
            )

            syncSection

            DataSettingsSection(
                showsCloudSyncRow: false,
                advancedDataOptionsTitle: "Delete or Reset Data",
                advancedDataOptionsSubtitle: "Delete all records, cancel reminders, or generate reports"
            )

            safetySection
        }
    }

    private var privacyExplanationSection: some View {
        SettingsSection(title: String(localized: "Privacy")) {
            VStack(spacing: 12) {
                NavigationLink(destination: PrivacyWalkthroughView()) {
                    SettingsRow(
                        icon: "hand.raised.shield.fill",
                        iconColor: themeManager.selectedColor,
                        title: String(localized: "Your Data Stays Yours"),
                        subtitle: String(localized: "Local storage, iCloud sync, app lock, export, deletion, and no tracking")
                    ) {
                        SettingsDisclosureIndicator()
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    privacyBullet("No third-party trackers or ad analytics", icon: "nosign")
                    privacyBullet("Local analytics do not include journal or thought-record text", icon: "chart.bar.doc.horizontal")
                    privacyBullet("Exports are created only when you choose to save or share them", icon: "square.and.arrow.up")
                }
                .padding(.leading, 2)
            }
        }
    }

    private var syncSection: some View {
        SettingsSection(title: String(localized: "Sync Status")) {
            SettingsRow(
                icon: "icloud.fill",
                iconColor: themeManager.selectedColor,
                title: String(localized: "iCloud Sync"),
                subtitle: cloudSyncSubtitle
            ) {
                SyncStatusIndicatorView(
                    monitor: syncStatusMonitor,
                    style: isCloudKitStoreEnabled ? .label : .dot
                )
            }

            NavigationLink(destination: SyncStorageAuditView()) {
                SettingsRow(
                    icon: "stethoscope",
                    iconColor: themeManager.selectedColor,
                    title: String(localized: "Sync & Storage Check"),
                    subtitle: String(localized: "Review iCloud health, storage mode, and repair tools")
                ) {
                    SettingsDisclosureIndicator()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var safetySection: some View {
        SettingsSection(title: String(localized: "Crisis Resources")) {
            NavigationLink(destination: SafetyPlanView()) {
                SettingsRow(
                    icon: "cross.case.fill",
                    iconColor: themeManager.selectedColor,
                    title: String(localized: "Rough Patch Plan"),
                    subtitle: String(localized: "Keep warning signs, grounding steps, and trusted contacts nearby")
                ) {
                    SettingsDisclosureIndicator()
                }
            }
            .buttonStyle(.plain)

            SettingsRow(
                icon: "phone.connection.fill",
                iconColor: Theme.errorRed,
                title: String(localized: "Immediate Help"),
                subtitle: String(localized: "If you may be in danger, call local emergency services. In the U.S., call or text 988 for crisis support.")
            )
        }
    }

    private func privacyBullet(_ text: LocalizedStringKey, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cloudSyncSubtitle: String {
        if isCloudKitStoreEnabled {
            return String(localized: "Syncing between iPhone, iPad, and Mac")
        }

        if !cloudKitFailureReason.isEmpty {
            return String(localized: "Using local storage: \(cloudKitFailureReason)")
        }

        return String(localized: "Using local storage until iCloud is available")
    }
}
