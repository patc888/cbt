import SwiftUI
import SwiftData

// MARK: - Sync Status View

struct SyncStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var auditService = StorageAuditService()
    @State private var showingPurgeConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cloudHealthSection
                dbAuditSection
                mediaCleanupSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Theme.secondaryBackground)
        .navigationTitle("Sync & Storage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            auditService.checkCloudStatus()
        }
        .alert("Purge Orphan Files", isPresented: $showingPurgeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Purge", role: .destructive) {
                HapticManager.shared.destructiveAction()
                auditService.purgeOrphanFiles()
            }
        } message: {
            Text("This will permanently delete \(auditService.orphanAssets.count) legacy file(s) (\(auditService.formattedOrphanSize)) from local storage. This cannot be undone.")
        }
    }

    // MARK: Sections

    private var cloudHealthSection: some View {
        SettingsSection(title: "CloudKit Health") {
            SettingsRow(icon: "icloud.fill", iconColor: themeManager.primaryColor, title: "Account Status") {
                Text(auditService.cloudAccountStatus)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor(for: auditService.cloudAccountStatus))
            }

            SettingsRow(icon: "clock.fill", iconColor: themeManager.primaryColor, title: "Last Checked") {
                Text(auditService.lastSyncTime)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Button {
                HapticManager.shared.lightImpact()
                auditService.checkCloudStatus()
            } label: {
                SettingsRow(icon: "arrow.clockwise", iconColor: themeManager.primaryColor, title: "Refresh Status") {
                    EmptyView()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var dbAuditSection: some View {
        SettingsSection(title: "Database Repair") {
            Button {
                HapticManager.shared.mediumImpact()
                auditService.auditAndRepair(context: modelContext)
            } label: {
                SettingsRow(
                    icon: "stethoscope",
                    iconColor: themeManager.primaryColor,
                    title: "Check & Repair Orphan Records",
                    subtitle: "Remove duplicate settings records and repair singleton data"
                ) {
                    if auditService.isAuditing {
                        ProgressView()
                            .tint(themeManager.primaryColor)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(auditService.isAuditing)

            if !auditService.auditResults.isEmpty {
                ForEach(auditService.auditResults, id: \.self) { result in
                    HStack(spacing: 8) {
                        Image(systemName: auditService.auditNeedsRepair ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(auditService.auditNeedsRepair ? .orange : Theme.successGreen)
                        Text(result)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var mediaCleanupSection: some View {
        SettingsSection(title: "Media Cleanup") {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryText)
                Text("Scans local storage for legacy files that are no longer referenced by current CBT records. Safe to remove.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Button {
                HapticManager.shared.mediumImpact()
                auditService.scanOrphanFiles()
            } label: {
                SettingsRow(
                    icon: "doc.text.magnifyingglass",
                    iconColor: themeManager.primaryColor,
                    title: "Scan for Orphan Files",
                    subtitle: auditService.isScanning ? "Scanning..." : "Identify legacy files taking up space"
                ) {
                    if auditService.isScanning {
                        ProgressView()
                            .tint(themeManager.primaryColor)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(auditService.isScanning || auditService.isPurging)

            if !auditService.scanResults.isEmpty {
                ForEach(auditService.scanResults, id: \.self) { result in
                    HStack(spacing: 8) {
                        Image(systemName: auditService.mediaNeedsRepair ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(auditService.mediaNeedsRepair ? .orange : Theme.successGreen)
                        Text(result)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }

            if !auditService.orphanAssets.isEmpty {
                VStack(spacing: 10) {
                    HStack {
                        Label {
                            Text("\(auditService.orphanAssets.count) Orphan Asset\(auditService.orphanAssets.count == 1 ? "" : "s")")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                        } icon: {
                            Image(systemName: "doc.badge.gearshape")
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(auditService.formattedOrphanSize)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)

                    Button {
                        HapticManager.shared.mediumImpact()
                        showingPurgeConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Purge Orphan Assets")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(auditService.isPurging)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Helpers

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Available": return Theme.successGreen
        case "Checking...": return Theme.secondaryText
        default: return .orange
        }
    }
}
