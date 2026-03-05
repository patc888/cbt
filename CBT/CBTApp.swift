import SwiftUI
import SwiftData

@main
struct CBTApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserSettings.self,
            MoodEntry.self,
            ThoughtRecord.self,
            ExerciseCompletion.self,
            JournalEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
