import SwiftData
import Foundation

enum CBTModelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [
            CBTVersionedSchemaV1.self,
            CBTVersionedSchemaV2.self,
            CBTVersionedSchemaV3.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: CBTVersionedSchemaV1.self, toVersion: CBTVersionedSchemaV2.self),
            .lightweight(fromVersion: CBTVersionedSchemaV2.self, toVersion: CBTVersionedSchemaV3.self)
        ]
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
            JournalEntry.self,
            PlannedActivity.self,
            AssessmentLog.self,
            PersonalityAssessmentLog.self
        ]
    }
}

enum CBTVersionedSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
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
            BreathingSession.self
        ]
    }
}

enum CBTVersionedSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}
