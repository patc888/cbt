import SwiftUI
import SwiftData

@main
struct CBTApp: App {
    @StateObject private var securityManager = SecurityManager.shared
    @State private var themeManager = ThemeManager()
    
    private static let schema = Schema([
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self
    ])
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(securityManager)
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
                .modelContainer(for: Self.schema)
                .blur(radius: securityManager.isContentProtected ? 20 : 0)
                .overlay {
                    if securityManager.isLocked {
                        SecurityCoverRoot()
                            .environment(themeManager)
                            .environmentObject(securityManager)
                    }
                }
        }
    }
}
