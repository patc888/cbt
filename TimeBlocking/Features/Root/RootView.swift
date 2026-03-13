import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]

    var body: some View {
        @Bindable var appState = appEnvironment.appState

        ZStack(alignment: .top) {
            NavigationStack {
                ScheduleView()
            }

            HStack(alignment: .center, spacing: 12) {
                Button {
                    appState.showDashboard()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .background(Theme.primaryPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Open stats")
                .padding(.leading, 16)

                Spacer()

                VStack(spacing: 2) {
                    Text("Schedule")
                        .font(.system(size: Theme.fontSizeSection, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text(appState.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)
                }

                Spacer()

                Button {
                    appState.showSettings()
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
                .padding(.trailing, 16)
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
        .overlay(alignment: .bottomTrailing) {
            floatingActionButton(
                systemImage: "plus"
            ) {
                appState.isPresentingAddModal = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .sheet(item: $appState.presentedSheet) { sheet in
            switch sheet {
            case .dashboard:
                secondarySurface(
                    title: "Stats",
                    accessibilityLabel: "Close stats"
                ) {
                    DashboardView()
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            case .templates:
                secondarySurface(
                    title: "Routines",
                    accessibilityLabel: "Close routines"
                ) {
                    TemplatesView()
                }
            case .premium:
                TimeSubscriptionView()
            }
        }
        .onChange(of: appState.selectedSection) { _, newSection in
            switch newSection {
            case .schedule:
                break
            case .dashboard:
                appState.showDashboard()
            case .templates:
                appState.showTemplates()
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

    private func floatingActionButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(Theme.primaryPurple.gradient)
                        .shadow(color: Theme.primaryPurple.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(.plain)
    }

    private func secondarySurface<Content: View>(
        title: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            content()

            HStack {
                Spacer()

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: Theme.fontSizeSection, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                }

                Spacer()

                Button {
                    appEnvironment.appState.showScheduleHome()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .background(Theme.primaryPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel(accessibilityLabel)
                .padding(.trailing, 16)
            }
            .frame(height: 64)
            .padding(.top, 4)
            .background(.ultraThinMaterial.opacity(0.6))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.1)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}
