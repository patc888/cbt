import SwiftData
import Foundation

enum CBTModelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [CBTVersionedSchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        // No stages yet as we are defining the baseline Version 1.0.0
        []
    }
}

enum CBTVersionedSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            UserSettings.self,
            MoodEntry.self,
            ThoughtRecord.self,
            ExerciseCompletion.self,
            JournalEntry.self
        ]
    }
}
