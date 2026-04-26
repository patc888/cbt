import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]
    @StateObject private var securityManager = SecurityManager.shared


    var body: some View {
        @Bindable var appState = appEnvironment.appState

        ZStack {
            VStack(spacing: 0) {
                if appEnvironment.isFallback {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Temporary Storage Mode: Changes will not be saved")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.orange)
                    .foregroundStyle(.white)
                    .adaptiveShadow(color: .black.opacity(0.1), radius: 5, y: 2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }


                ScheduleView()
            }
            .background {
                AuroraBackground()
                    .ignoresSafeArea()
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
            .padding(.bottom, 36)
        }
        .sheet(item: Binding<TimePresentedSheet?>(
            get: { appState.presentedSheet == .templates ? .templates : nil },
            set: { if $0 == nil && appState.presentedSheet == .templates { appState.presentedSheet = nil } }
        )) { _ in
            secondarySurface(
                title: "Routines",
                accessibilityLabel: "Close routines"
            ) {
                TemplatesView()
            }
        }
        .overlay {
            if appState.presentedSheet != nil && appState.presentedSheet != .templates {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            appState.showScheduleHome()
                        }
                    }
                    .zIndex(5)
            }
        }
        .overlay {
            Group {
                if appState.presentedSheet == .dashboard {
                    DashboardView()
                        .transition(.move(edge: .leading))
                        .adaptiveShadow(color: .black.opacity(0.1), radius: 20, x: 10, y: 0)
                }

                if appState.presentedSheet == .settings {
                    SettingsView()
                        .transition(.move(edge: .trailing))
                        .adaptiveShadow(color: .black.opacity(0.1), radius: 20, x: -10, y: 0)
                }
            }
            .zIndex(10)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.presentedSheet)
        .onChange(of: appState.selectedSection) { _, newSection in
            switch newSection {
            case .dashboard: appState.showDashboard()
            case .templates: appState.showTemplates()
            case .schedule: appState.showScheduleHome()
            }
        }
        .task {
            if preferences.first?.appLockEnabled ?? false {
                securityManager.lock()
                securityManager.authenticate()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await appEnvironment.resyncNotifications(using: modelContext)
                }

                if preferences.first?.appLockEnabled ?? false {
                    securityManager.authenticate()
                }
            } else if newPhase == .background || newPhase == .inactive {
                if preferences.first?.appLockEnabled ?? false {
                    securityManager.lock()
                }
            }
        }
        .preferredColorScheme(preferences.first?.appTheme?.colorScheme)
        .overlay {
            if (preferences.first?.appLockEnabled ?? false) && securityManager.isLocked {
                LockView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            
            // Privacy blur when app is in switcher
            if (preferences.first?.appLockEnabled ?? false) && scenePhase != .active {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .zIndex(101)
            }
        }
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
                        .fill(Theme.primaryAccent)
                        .adaptiveShadow(color: Theme.primaryAccent.opacity(0.35), radius: 15, x: 0, y: 8)
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

            VStack(spacing: 0) {
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
                            .foregroundStyle(Theme.primaryAccent)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                            .background(Theme.primaryAccent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(accessibilityLabel)
                    .padding(.trailing, 16)
                }
                .frame(height: 32)
                .padding(.top, 4)

                Divider()
                    .opacity(0.1)
            }
            .background {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

}

#Preview {
    RootView()
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}
