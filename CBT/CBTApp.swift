import OSLog
import SwiftData
import SwiftUI

@main
struct CBTApp: App {
    private enum LaunchState {
        case loading
        case ready(ModelContainer)
        case repair
    }

    fileprivate enum BootstrapStage: String {
        case primary = "primary"
        case primaryRecovery = "primary-recovery"
        case fallback = "fallback-local"
    }

    fileprivate enum BootstrapError: Error {
        case debugInjectedFailure(String)
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "AppBootstrap"
    )

    private static let schema = Schema([
        Item.self,
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self
    ])

    @State private var launchState: LaunchState
    @State private var resetID = UUID()
    @State private var themeManager = ThemeManager()

    init() {
        _launchState = State(initialValue: Self.bootstrap(reason: "app launch"))
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: .didResetData)) { _ in
                    themeManager = ThemeManager()
                    bootstrapIntoCurrentState(reason: "local reset")
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch launchState {
        case .loading:
            DataRepairLoadingView()
        case .ready(let container):
            ContentView()
                .id(resetID)
                .modelContainer(container)
        case .repair:
            DataRepairView(
                onRetry: {
                    bootstrapIntoCurrentState(reason: "repair retry")
                },
                onResetThisDevice: {
                    launchState = .loading
                    DataResetManager.shared.performLocalWipe()
                }
            )
        }
    }

    @MainActor
    private func bootstrapIntoCurrentState(reason: String) {
        launchState = .loading
        let nextState = Self.bootstrap(reason: reason)
        if case .ready = nextState {
            resetID = UUID()
        }
        launchState = nextState
    }

    private static func bootstrap(reason: String) -> LaunchState {
        do {
            return .ready(try makePrimaryContainer(stage: .primary))
        } catch {
            logBootstrapFailure(error, stage: .primary, reason: reason)
        }

        do {
            if try DataResetManager.shared.quarantineDefaultStoreForRepair() != nil {
                logger.notice("Quarantined the default store before retrying model bootstrap.")
            }
        } catch {
            logHousekeepingFailure(error, action: "quarantine-default-store")
        }

        do {
            return .ready(try makePrimaryContainer(stage: .primaryRecovery))
        } catch {
            logBootstrapFailure(error, stage: .primaryRecovery, reason: reason)
        }

        do {
            try DataResetManager.shared.removeFallbackStoreFiles()
        } catch {
            logHousekeepingFailure(error, action: "clear-fallback-store")
        }

        do {
            logger.notice("Launching with an isolated local fallback store.")
            return .ready(try makeFallbackContainer())
        } catch {
            logBootstrapFailure(error, stage: .fallback, reason: reason)
            return .repair
        }
    }

    private static func makePrimaryContainer(stage: BootstrapStage) throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: stage)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func makeFallbackContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .fallback)

        let configuration = ModelConfiguration(
            "LocalRecovery",
            schema: schema,
            url: DataResetManager.shared.fallbackStoreURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func logBootstrapFailure(
        _ error: Error,
        stage: BootstrapStage,
        reason: String
    ) {
        let nsError = error as NSError
        logger.error(
            "Model bootstrap failed stage=\(stage.rawValue, privacy: .public) reason=\(reason, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    private static func logHousekeepingFailure(_ error: Error, action: String) {
        let nsError = error as NSError
        logger.error(
            "Bootstrap recovery housekeeping failed action=\(action, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }
}

private enum DebugBootstrapControl {
    #if DEBUG
    private static let launchArguments = ProcessInfo.processInfo.arguments
    private static let failAllStores = launchArguments.contains("-debug-modelcontainer-fail-all")
    private static var remainingPrimaryFailures = launchArguments.contains("-debug-modelcontainer-fail-primary-once") ? 1 : 0
    #endif

    static func injectFailureIfNeeded(for stage: CBTApp.BootstrapStage) throws {
        #if DEBUG
        if failAllStores {
            throw CBTApp.BootstrapError.debugInjectedFailure(stage.rawValue)
        }

        if stage == .primary, remainingPrimaryFailures > 0 {
            remainingPrimaryFailures -= 1
            throw CBTApp.BootstrapError.debugInjectedFailure(stage.rawValue)
        }
        #endif
    }
}

private struct DataRepairLoadingView: View {
    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ProgressView("Opening your data...")
                .font(DSTypography.body)
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
        }
    }
}

private struct DataRepairView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onRetry: () -> Void
    let onResetThisDevice: () -> Void

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Label {
                                Text("Data Repair")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                            } icon: {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(themeManager.primaryColor)
                            }

                            Text("Something went wrong while opening your data on this device.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)

                            Text("You can try again, or reset local data on this device. Resetting this device does not delete iCloud data.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 12) {
                        DSPrimaryButton(title: "Retry", action: onRetry)

                        Button("Reset This Device", action: onResetThisDevice)
                            .font(DSTypography.button)
                            .foregroundStyle(Theme.errorRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.large)
                            .background(Theme.errorRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
                            .accessibilityHint("Deletes local app data and preferences on this device only.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .responsiveMaxWidth(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
