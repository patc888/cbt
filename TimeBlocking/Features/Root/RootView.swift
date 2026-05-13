import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]
    @StateObject private var securityManager = SecurityManager.shared

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    private var isAppLockEnabled: Bool {
        appPreferences?.appLockEnabled ?? false
    }

    private var appColorScheme: ColorScheme? {
        appPreferences?.appThemeValue.colorScheme
    }


    var body: some View {
        rootContent
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .overlay(alignment: .bottomTrailing, content: addButtonOverlay)
        .sheet(item: Binding<TimePresentedSheet?>(
            get: { appEnvironment.appState.presentedSheet == .templates ? .templates : nil },
            set: { if $0 == nil && appEnvironment.appState.presentedSheet == .templates { appEnvironment.appState.presentedSheet = nil } }
        )) { _ in
            secondarySurface(
                title: "Routines",
                accessibilityLabel: "Close routines"
            ) {
                TemplatesView()
            }
        }
        .overlay(content: dimmingOverlay)
        .overlay(content: sidePanelOverlay)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appEnvironment.appState.presentedSheet)
        .onChange(of: appEnvironment.appState.selectedSection) { _, newSection in
            switch newSection {
            case .dashboard: appEnvironment.appState.showDashboard()
            case .templates: appEnvironment.appState.showTemplates()
            case .schedule: appEnvironment.appState.showScheduleHome()
            }
        }
        .task {
            if isAppLockEnabled {
                securityManager.lock()
                securityManager.authenticate()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await appEnvironment.resyncNotifications(using: modelContext)
                }

                if isAppLockEnabled {
                    securityManager.authenticate()
                }
            } else if newPhase == .background || newPhase == .inactive {
                if isAppLockEnabled {
                    securityManager.lock()
                }
            }
        }
        .preferredColorScheme(appColorScheme)
        .overlay(content: securityOverlay)
    }

    private var rootContent: some View {
        ZStack {
            VStack(spacing: 0) {
                fallbackBanner
                ScheduleView()
            }
            .background {
                AuroraBackground()
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var fallbackBanner: some View {
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
    }

    @ViewBuilder
    private func addButtonOverlay() -> some View {
        if appEnvironment.appState.presentedSheet == nil {
            floatingActionButton(systemImage: "plus") {
                appEnvironment.appState.isPresentingAddModal = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 36)
            .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func dimmingOverlay() -> some View {
        let shouldDim = appEnvironment.appState.presentedSheet != nil
            && appEnvironment.appState.presentedSheet != .templates
        if shouldDim {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        appEnvironment.appState.showScheduleHome()
                    }
                }
                .zIndex(5)
        }
    }

    @ViewBuilder
    private func sidePanelOverlay() -> some View {
        Group {
            if appEnvironment.appState.presentedSheet == .dashboard {
                DashboardView()
                    .transition(.move(edge: .leading))
                    .adaptiveShadow(color: .black.opacity(0.1), radius: 20, x: 10, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width < -80 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        appEnvironment.appState.showScheduleHome()
                                    }
                                }
                            }
                )
            }

            if shouldPresentSettingsAsPopup && appEnvironment.appState.presentedSheet == .settings {
                SettingsView()
                    .frame(width: 540, height: 720)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .adaptiveShadow(color: .black.opacity(0.18), radius: 24, y: 12)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else if appEnvironment.appState.presentedSheet == .settings {
                SettingsView()
                    .transition(.move(edge: .trailing))
                    .adaptiveShadow(color: .black.opacity(0.1), radius: 20, x: -10, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width > 80 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        appEnvironment.appState.showScheduleHome()
                                    }
                                }
                            }
                    )
            }
        }
        .zIndex(10)
    }

    private var shouldPresentSettingsAsPopup: Bool {
#if os(macOS)
        true
#elseif os(iOS)
        ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac
#else
        false
#endif
    }

    @ViewBuilder
    private func securityOverlay() -> some View {
        if isAppLockEnabled && securityManager.isLocked {
            LockView()
                .transition(.opacity)
                .zIndex(100)
        }

        if isAppLockEnabled && scenePhase != .active {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .zIndex(101)
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
