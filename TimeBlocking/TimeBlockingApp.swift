import SwiftUI
import SwiftData

@MainActor
@main
struct TimeBlockingApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
        }
        .modelContainer(appEnvironment.persistenceController.container)
    }
}
