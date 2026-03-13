import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @Query private var preferences: [AppPreferences]

    var body: some View {
        @Bindable var appState = appEnvironment.appState

        ZStack(alignment: .top) {
            Color.clear

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
                        .navigationTitle("Time Blocking")
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

            HStack(alignment: .center, spacing: 12) {
                Button {
                    appEnvironment.appState.showSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .background(Theme.primaryPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Open settings")
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

                if appState.selectedSection == .schedule {
                    Button {
                        appState.isPresentingAddModal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.primaryPurple)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                            .background(Theme.primaryPurple.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Add block")
                    .padding(.trailing, 16)
                } else {
                    Color.clear
                        .frame(width: 36, height: 36)
                        .padding(.trailing, 16)
                }
            }
            .frame(height: 64)
            .padding(.top, 4)
            .background(.ultraThinMaterial.opacity(0.6))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.1)
            }
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
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
            await appEnvironment.resyncNotifications(using: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await appEnvironment.resyncNotifications(using: modelContext)
            }
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
