import SwiftUI
import SwiftData

@MainActor
@main
struct TimeBlockingApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appEnvironment.isReady, let controller = appEnvironment.persistenceController {
                    RootView()
                        .environment(appEnvironment)
                        .modelContainer(controller.container)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                } else {
                    LoadingView()
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.8), value: appEnvironment.isReady)
            .task {
                await appEnvironment.initialize()
            }

        }
    }
}
