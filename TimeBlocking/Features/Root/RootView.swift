import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Query private var preferences: [AppPreferences]

    @AppStorage("userTheme") private var userTheme: String = "System"
    @AppStorage("appColorTheme") private var appColorTheme: String = "Purple"
    @AppStorage("appThemeImmersive") private var appThemeImmersive: Bool = true

    var body: some View {
        @Bindable var appState = appEnvironment.appState

        ZStack(alignment: .top) {
            Color.clear // AuroraBackground is now handled by feature views and sheets

            Group {
                if usesCompactTabs {
                    TabView(selection: $appState.selectedSection) {
                        ForEach(AppSection.allCases) { section in
                            NavigationStack {
                                detailView(for: section)
                            }
                            .tabItem {
                                Label(section.title, systemImage: section.systemImage)
                            }
                            .tag(section)
                        }
                    }
                } else {
                    let selectedSection = Binding<AppSection?>(
                        get: { appState.selectedSection },
                        set: { if let value = $0 { appState.selectedSection = value } }
                    )

                    NavigationSplitView {
                        List(AppSection.allCases, selection: selectedSection) { section in
                            Label(section.title, systemImage: section.systemImage)
                                .tag(section)
                        }
                        .navigationTitle("Time")
#if os(macOS)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
#endif
                    } detail: {
                        NavigationStack {
                            detailView(for: appState.selectedSection)
                        }
                    }
                }
            }

            // Custom Top Shell - Donor Style
            HStack(alignment: .center) {
                Button(action: {
                    appEnvironment.appState.showSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple)
                        .padding(10)
                        .contentShape(Circle())
                        .background(Theme.primaryPurple.opacity(0.12))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(appState.selectedSection.title)
                        .font(.system(size: Theme.fontSizeSection, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    if appState.selectedSection == .schedule {
                        Text(appState.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.primaryPurple)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if appState.selectedSection != .dashboard {
                        Button(action: {
                            appState.isPresentingAddModal = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.primaryPurple)
                                .padding(10)
                                .contentShape(Circle())
                                .background(Theme.primaryPurple.opacity(0.12))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: {
                        appEnvironment.appState.showPremium()
                    }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.primaryPurple)
                            .padding(10)
                            .contentShape(Circle())
                            .background(Theme.primaryPurple.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 64)
            .padding(.top, 4)
            .background(.ultraThinMaterial.opacity(0.6))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.1)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $appState.presentedSheet) { sheet in
            switch sheet {
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            case .premium:
                TimeSubscriptionView()
            }
        }
        .task {
            appEnvironment.prepareIfNeeded(using: modelContext)
        }
        .preferredColorScheme(preferences.first?.appTheme?.colorScheme)
    }

    private var usesCompactTabs: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .schedule:
            ScheduleView()
        case .templates:
            TemplatesView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}
