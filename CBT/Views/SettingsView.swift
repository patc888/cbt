import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var settings: [UserSettings]
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var metrics: LayoutMetrics { LayoutMetrics.metrics(for: horizontalSizeClass) }
    
    @State private var showingSubscription = false
    @State private var showingDebug = false
    @State private var showingExportInfo = false
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    private let dataExportService = DataExportService()
    
    var userSettings: UserSettings? { settings.first }
    var showsDismissControl: Bool = true
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainContent
                }
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: 600)

            if showsDismissControl {
                navigationArrow
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
        }
#if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .sheet(isPresented: $showingDebug) {
            NavigationStack {
                Text("Debug Placeholder (Chores debug views were stripped)")
                    .navigationTitle("Debug")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
        .sheet(isPresented: $showingExportInfo) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: "Export Your Data",
                    subtitle: "Create a JSON file from your local entries that you can save or share.",
                    bullets: [
                        DSBullet(icon: "checkmark.circle", text: "Includes moods, thought records, and exercises"),
                        DSBullet(icon: "lock.fill", text: "Generated locally on your device"),
                        DSBullet(icon: "square.and.arrow.up", text: "You choose where to share or store it")
                    ],
                    primaryTitle: "Export",
                    primaryAction: {
                        HapticManager.shared.mediumImpact()
                        showingExportInfo = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            exportData()
                        }
                    },
                    secondaryTitle: "Cancel",
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        showingExportInfo = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingExportInfo = false
                    }
                )
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            if let exportFileURL {
                ActivityViewController(items: [exportFileURL])
            }
        }
        #endif
        .task {
            let enabled = userSettings?.hapticsEnabled ?? true
            if userSettings?.hapticsEnabled == nil {
                userSettings?.hapticsEnabled = enabled
                try? modelContext.save()
            }
            HapticManager.shared.setEnabled(enabled)
            await subscriptionManager.loadProducts()
        }
        #if os(macOS)
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
                .frame(minWidth: 600, minHeight: 600)
        }
        #else
        .fullScreenCover(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        #endif
        .onChange(of: userSettings?.hapticsEnabled ?? true) { _, enabled in
            HapticManager.shared.setEnabled(enabled)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            SettingsSection(title: "Education") {
                NavigationLink(destination: CBTEducationMenuView()) {
                    SettingsRow(
                        icon: "brain.head.profile",
                        iconColor: themeManager.primaryColor,
                        title: "Learn About CBT"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            
            SubscriptionSettingsView(
                subscriptionManager: subscriptionManager,
                showingSubscription: $showingSubscription
            )
            
            AppearanceSettingsView(
                userTheme: Bindable(themeManager).appTheme,
                selectedTheme: Bindable(themeManager).selectedTheme,
                isImmersive: Bindable(themeManager).isImmersive,
                hapticsEnabled: Binding(
                    get: { userSettings?.hapticsEnabled ?? true },
                    set: {
                        userSettings?.hapticsEnabled = $0
                        HapticManager.shared.setEnabled($0)
                        try? modelContext.save()
                    }
                ),
                currentIcon: Binding(
                    get: { userSettings?.currentIcon },
                    set: { userSettings?.currentIcon = $0; try? modelContext.save() }
                )
            )
            
            if let settings = userSettings {
                SecuritySettingsView(settings: settings)
            }

            DataSettingsSection()

            SettingsSection(title: "Tools") {
                NavigationLink(destination: BreathingResetView()) {
                    SettingsRow(
                        icon: "wind",
                        iconColor: themeManager.primaryColor,
                        title: "Breathing Reset",
                        subtitle: "Guided box breathing session"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }

            RemindersSettingsSection()
            
            AboutSettingsView()
            
            VStack(alignment: .leading, spacing: 12) {
                SettingsSection(title: "Advanced") {
                    #if DEBUG
                    Button {
                        HapticManager.shared.lightImpact()
                        showingDebug = true
                    } label: {
                        SettingsRow(icon: "ladybug", iconColor: themeManager.primaryColor, title: "Debug Tools") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                         }
                    }
                    .buttonStyle(.plain)
                    #endif
                    
                    Button {
                        HapticManager.shared.lightImpact()
                        showingExportInfo = true
                    } label: {
                        SettingsRow(icon: "square.and.arrow.up", iconColor: themeManager.primaryColor, title: "Export Data") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataResetOptionsView()) {
                        SettingsRow(icon: "trash", iconColor: Theme.errorRed, title: "Reset All Data") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Text("This section contains data tools.")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private func exportData() {
        do {
            let fileURL = try dataExportService.exportDataFileURL(from: modelContext)
            exportFileURL = fileURL
            #if canImport(UIKit)
            showingShareSheet = true
            #endif
        } catch {
            print("Error exporting data: \(error)")
        }
    }

    private var navigationArrow: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            dismiss()
        }) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(themeManager.primaryColor)
                .padding(8)
                .contentShape(Rectangle())
        }
        .padding(.trailing, 20)
        .padding(.top, 12)
    }
}

#if canImport(UIKit)
private struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
