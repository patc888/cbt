import SwiftUI

#if DEBUG
struct LocalRetentionDashboardView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var events = [RetentionEvent]()
    @State private var snapshot: RetentionAggregationSnapshot?
    @State private var errorMessage: String?
    @State private var showingClearConfirmation = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            if let snapshot {
                Section("Onboarding") {
                    metric("Started", "\(snapshot.onboardingStarted)")
                    metric("Completed", "\(snapshot.onboardingCompleted)")
                    metric("Skipped", "\(snapshot.onboardingSkipped)")
                }

                Section("Activation") {
                    metric("Events", "\(snapshot.eventCount)")
                    metric("First-session activation", snapshot.firstSessionActivated ? "Yes" : "No")
                    metric("First mood check-in", snapshot.firstMoodCheckInCompleted ? "Yes" : "No")
                    metric("Daily Plan funnel", "\(snapshot.firstDailyPlanItemCompleted) first items, \(snapshot.dailyPlanCompleted) completed plans")
                    metric("Weekly review engagement", "\(snapshot.weeklyReportViewed)")
                }

                Section("Notifications") {
                    metric("Prompt shown", "\(snapshot.notificationPromptShown)")
                    metric("Permission requested", "\(snapshot.notificationPermissionRequested)")
                    metric("Permission granted", "\(snapshot.notificationPermissionGranted)")
                    metric("Permission denied", "\(snapshot.notificationPermissionDenied)")
                }

                Section("Retention") {
                    metric("D1 / D3 / D7 returns", "\(yn(snapshot.returnedD1)) / \(yn(snapshot.returnedD3)) / \(yn(snapshot.returnedD7))")
                    metric("Streak started", "\(snapshot.streakStarted)")
                    metric("Streak broken", "\(snapshot.streakBroken)")
                    metric("Streak recovered", "\(snapshot.streakRecovered)")
                }

                Section("Product") {
                    metric("Achievements unlocked", "\(snapshot.achievementsUnlocked)")
                    metric("Paywall shown", "\(snapshot.paywallShown)")
                    metric("Purchased", "\(snapshot.purchaseCompleted)")
                    metric("Restored", "\(snapshot.purchaseRestored)")
                }
            }

            Section("Local Actions") {
                Button {
                    export()
                } label: {
                    Label("Prepare Local JSON Export", systemImage: "square.and.arrow.up")
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Local JSON Export", systemImage: "doc.text")
                    }
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear Local Event Data", systemImage: "trash")
                }
            }

            Section("Recent Events") {
                if events.isEmpty {
                    Text("No local retention events yet.")
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    ForEach(events.prefix(80), id: \.id) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.eventName)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                            if let sourceScreen = event.sourceScreen {
                                Text(sourceScreen)
                                    .font(.caption)
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Local Retention")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            reload()
        }
        .alert("Clear Local Retention Events?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clear()
            }
        } message: {
            Text("This only clears local product analytics events stored on this device.")
        }
        .alert("Local Retention Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func yn(_ value: Bool) -> String {
        value ? "Y" : "N"
    }

    @MainActor
    private func reload() {
        do {
            events = try LocalRetentionEventStore.shared.events()
            snapshot = try LocalRetentionEventStore.shared.aggregationSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clear() {
        do {
            try LocalRetentionEventStore.shared.clearAll()
            exportURL = nil
            reload()
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func export() {
        do {
            let data = try LocalRetentionEventStore.shared.exportData()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("cbt-local-retention-events.json")
            try data.write(to: url, options: [.atomic])
            exportURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
