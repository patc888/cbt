import SwiftUI
import SwiftData

@main
struct CBTApp: App {
    // Make the container dynamic so it can be recreated on wipe
    @State private var sharedModelContainer: ModelContainer = CBTApp.createModelContainer()

    // Key to rebuild the main UI stack
    @State private var resetID = UUID()

    static func createModelContainer() -> ModelContainer {
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
            // Re-throw or ignore? A real failure here is critical.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
                .id(resetID)
                .onReceive(NotificationCenter.default.publisher(for: .didResetData)) { _ in
                    // In-place recreate the container + views
                    sharedModelContainer = Self.createModelContainer()
                    resetID = UUID()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
