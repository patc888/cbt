import SwiftUI
import SwiftData

@MainActor
@main
struct TimeBlockingApp: App {
    @State private var appEnvironment = AppEnvironment()
    
    init() {
        // Initialize subscription manager at app launch to start listening for transactions
        _ = SubscriptionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appEnvironment.isReady, let persistenceController = appEnvironment.persistenceController {
                    RootView()
                        .environment(appEnvironment)
                        .modelContainer(persistenceController.container)
                } else {
                    LoadingView()
                }
            }
            .task {
                await appEnvironment.initialize()
            }
        }
    }
}
