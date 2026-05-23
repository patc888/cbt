import Foundation
import SwiftData

enum SharedPersistence {
    static let cloudKitContainerID = AppConfiguration.cloudKitContainerIdentifier
    static let storeFileName = "default.store"

    static let schema = Schema([
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self,
        PlannedActivity.self,
        AssessmentLog.self,
        PersonalityAssessmentLog.self,
        ProgramProgress.self,
        FlexibleJournalEntry.self,
        MoodCheckIn.self,
        BreathingSession.self,
        SafetyPlan.self
    ])

    // MARK: - Factory

    /// Creates a `ModelContainer` with optional CloudKit backing.
    /// - Parameters:
    ///   - storeURL: An explicit file URL for the SQLite store. Pass `nil` to use SwiftData's default location.
    ///   - cloudKitEnabled: Whether to enable CloudKit sync via the private database.
    static func makeModelContainer(
        storeURL: URL? = defaultStoreURL,
        cloudKitEnabled: Bool = true
    ) throws -> ModelContainer {
        if let storeURL {
            try prepareStoreLocation(at: storeURL)
            ModelContainerRecovery.clearLaunchBlockingExtendedAttributes(for: storeURL)
        }

        let configuration: ModelConfiguration

        if let storeURL {
            configuration = ModelConfiguration(
                "Default",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitEnabled ? .private(cloudKitContainerID) : .none
            )
        } else {
            configuration = ModelConfiguration(
                "Default",
                schema: schema,
                cloudKitDatabase: cloudKitEnabled ? .private(cloudKitContainerID) : .none
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Uses the app's own Application Support directory instead of an App Group.
    static var defaultStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    private static func prepareStoreLocation(at storeURL: URL) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    /// Creates a purely in-memory container (for tests or as a last-resort recovery).
    static func makeInMemoryModelContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
