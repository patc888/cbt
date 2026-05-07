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
            RootView()
                .environment(appEnvironment)
                .modelContainer(appEnvironment.persistenceController?.container ?? PersistenceController.shared.container)
                .task {
                    await appEnvironment.initialize()
                }
        }
    }
}
