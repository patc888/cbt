import Foundation
import SwiftData

enum SharedPersistence {
    static let cloudKitContainerID = AppConfiguration.cloudKitContainerIdentifier
    static let storeFileName = "default.store"

    private static let modelRegistry: [PersistentModelRegistration] = [
        PersistentModelRegistration(UserSettings.self),
        PersistentModelRegistration(MoodEntry.self),
        PersistentModelRegistration(ThoughtRecord.self),
        PersistentModelRegistration(ExerciseCompletion.self),
        PersistentModelRegistration(JournalEntry.self),
        PersistentModelRegistration(PlannedActivity.self),
        PersistentModelRegistration(AssessmentLog.self),
        PersistentModelRegistration(PersonalityAssessmentLog.self),
        PersistentModelRegistration(ProgramProgress.self),
        PersistentModelRegistration(ChallengeSession.self),
        PersistentModelRegistration(FlexibleJournalEntry.self),
        PersistentModelRegistration(MoodCheckIn.self),
        PersistentModelRegistration(BreathingSession.self),
        PersistentModelRegistration(SafetyPlan.self),
        PersistentModelRegistration(LibraryItem.self),
        PersistentModelRegistration(Course.self),
        PersistentModelRegistration(Achievement.self),
        PersistentModelRegistration(AudioContent.self),
        PersistentModelRegistration(TinyWinCompletion.self),
        PersistentModelRegistration(WeeklyRitualEntry.self),
        PersistentModelRegistration(FirstSevenDaysJourney.self),
        PersistentModelRegistration(PersonalValue.self),
        PersistentModelRegistration(ValueActionCompletion.self),
        PersistentModelRegistration(OutcomeGoal.self),
        PersistentModelRegistration(DailyPlanCompletion.self),
        PersistentModelRegistration(HelpfulnessFeedback.self)
    ]

    static let currentModelTypes = modelRegistry.map(\.modelType)
    static let schema = Schema(currentModelTypes)

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

        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [makeModelConfiguration(storeURL: storeURL, cloudKitEnabled: cloudKitEnabled)]
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

    private static func makeModelConfiguration(
        storeURL: URL?,
        cloudKitEnabled: Bool
    ) -> ModelConfiguration {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = cloudKitEnabled
            ? .private(cloudKitContainerID)
            : .none

        if let storeURL {
            return ModelConfiguration(
                "Default",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitDatabase
            )
        }

        return ModelConfiguration(
            "Default",
            schema: schema,
            cloudKitDatabase: cloudKitDatabase
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

    static func deleteAllModelRecords(in modelContext: ModelContext) throws {
        for registration in modelRegistry {
            try registration.deleteAllRecords(modelContext)
        }

        try modelContext.save()
    }

    private struct PersistentModelRegistration {
        let modelType: any PersistentModel.Type
        let deleteAllRecords: (ModelContext) throws -> Void

        init<Model: PersistentModel>(_ modelType: Model.Type) {
            self.modelType = modelType
            self.deleteAllRecords = { modelContext in
                for record in try modelContext.fetch(FetchDescriptor<Model>()) {
                    modelContext.delete(record)
                }
            }
        }
    }
}
