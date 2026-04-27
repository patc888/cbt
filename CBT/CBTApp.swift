import SwiftUI
import SwiftData

@main
struct CBTApp: App {
    // Basic shared state for views
    @StateObject private var securityManager = SecurityManager.shared
    @State private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(securityManager)
                .environment(themeManager)
                .modelContainer(for: [
                    UserSettings.self,
                    MoodEntry.self,
                    ThoughtRecord.self,
                    ExerciseCompletion.self,
                    JournalEntry.self
                ])
                .overlay {
                    if securityManager.isLocked {
                        SecurityCoverRoot()
                            .environment(themeManager)
                            .environmentObject(securityManager)
                    }
                }
                .task {
                    // Perform non-blocking biometrics check after launch
                    try? await Task.sleep(for: .milliseconds(200))
                    await securityManager.checkBiometrics()
                }
        }
    }
}
