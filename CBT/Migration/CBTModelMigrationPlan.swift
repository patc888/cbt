import Foundation
import SwiftData

enum CBTModelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [
            CBTVersionedSchemaV1.self,
            CBTVersionedSchemaV2.self,
            CBTVersionedSchemaV3.self,
            CBTVersionedSchemaV4.self,
            CBTVersionedSchemaV5.self,
            CBTVersionedSchemaV6.self,
            CBTVersionedSchemaV7.self,
            CBTVersionedSchemaV8.self,
            CBTVersionedSchemaV9.self,
            CBTVersionedSchemaV10.self,
            CBTVersionedSchemaV11.self,
            CBTVersionedSchemaV12.self,
            CBTVersionedSchemaV13.self,
            CBTVersionedSchemaV14.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: CBTVersionedSchemaV1.self, toVersion: CBTVersionedSchemaV2.self),
            .lightweight(fromVersion: CBTVersionedSchemaV2.self, toVersion: CBTVersionedSchemaV3.self),
            .lightweight(fromVersion: CBTVersionedSchemaV3.self, toVersion: CBTVersionedSchemaV4.self),
            .lightweight(fromVersion: CBTVersionedSchemaV4.self, toVersion: CBTVersionedSchemaV5.self),
            .lightweight(fromVersion: CBTVersionedSchemaV5.self, toVersion: CBTVersionedSchemaV6.self),
            .lightweight(fromVersion: CBTVersionedSchemaV6.self, toVersion: CBTVersionedSchemaV7.self),
            .lightweight(fromVersion: CBTVersionedSchemaV7.self, toVersion: CBTVersionedSchemaV8.self),
            .lightweight(fromVersion: CBTVersionedSchemaV8.self, toVersion: CBTVersionedSchemaV9.self),
            .lightweight(fromVersion: CBTVersionedSchemaV9.self, toVersion: CBTVersionedSchemaV10.self),
            .lightweight(fromVersion: CBTVersionedSchemaV10.self, toVersion: CBTVersionedSchemaV11.self),
            .lightweight(fromVersion: CBTVersionedSchemaV11.self, toVersion: CBTVersionedSchemaV12.self),
            .lightweight(fromVersion: CBTVersionedSchemaV12.self, toVersion: CBTVersionedSchemaV13.self),
            .lightweight(fromVersion: CBTVersionedSchemaV13.self, toVersion: CBTVersionedSchemaV14.self)
        ]
    }
}

enum CBTVersionedSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Self.UserSettings.self,
            Self.MoodEntry.self,
            Self.ThoughtRecord.self,
            Self.ExerciseCompletion.self,
            Self.JournalEntry.self,
            Self.PlannedActivity.self,
            Self.AssessmentLog.self,
            Self.PersonalityAssessmentLog.self
        ]
    }

    @Model
    final class UserSettings {
        var singletonID: String = "default"
        var uuid: UUID? = UUID()
        var hapticsEnabled: Bool? = true
        var currentIcon: String?
        var appLockEnabled: Bool? = false
        var isPremium: Bool? = false

        init() {}
    }

    @Model
    final class MoodEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var emotionsStorage: String = ""
        var notes: String?
        var isDeleted: Bool = false
        var intensity: Int?
        var triggersStorage: String?

        init() {}
    }

    @Model
    final class ThoughtRecord {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var situation: String = ""
        var automaticThought: String = ""
        var emotionsStorage: String = ""
        var distortionsStorage: String = ""
        var evidenceFor: String = ""
        var evidenceAgainst: String = ""
        var balancedThought: String = ""
        var intensityBefore: Int = 0
        var intensityAfter: Int = 0
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class ExerciseCompletion {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var exerciseID: String = ""
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var title: String = ""
        var body: String = ""
        var sourceKind: String?
        var sourceID: String?
        var durationSeconds: Int?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class PlannedActivity {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var isDeleted: Bool = false
        var title: String = ""
        var activityDescription: String = ""
        var category: String = "Nourishing"
        var scheduledDate: Date = Date()
        var predictedEnjoyment: Int = 5
        var actualEnjoyment: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var notes: String?

        init() {}
    }

    @Model
    final class AssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var assessmentType: String = ""
        var score: Int = 0
        var scoreValue: Double?

        init() {}
    }

    @Model
    final class PersonalityAssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var opennessScore: Double = 0
        var conscientiousnessScore: Double = 0
        var extraversionScore: Double = 0
        var agreeablenessScore: Double = 0
        var neuroticismScore: Double = 0

        init() {}
    }
}

enum CBTVersionedSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            Self.UserSettings.self,
            Self.MoodEntry.self,
            Self.ThoughtRecord.self,
            Self.ExerciseCompletion.self,
            Self.JournalEntry.self,
            Self.PlannedActivity.self,
            Self.AssessmentLog.self,
            Self.PersonalityAssessmentLog.self,
            Self.ProgramProgress.self,
            Self.FlexibleJournalEntry.self,
            Self.MoodCheckIn.self,
            Self.BreathingSession.self
        ]
    }

    @Model
    final class UserSettings {
        var singletonID: String = "default"
        var uuid: UUID? = UUID()
        var hapticsEnabled: Bool? = true
        var currentIcon: String?
        var appLockEnabled: Bool? = false
        var isPremium: Bool? = false

        init() {}
    }

    @Model
    final class MoodEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var emotionsStorage: String = ""
        var notes: String?
        var isDeleted: Bool = false
        var intensity: Int?
        var triggersStorage: String?

        init() {}
    }

    @Model
    final class ThoughtRecord {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var situation: String = ""
        var automaticThought: String = ""
        var emotionsStorage: String = ""
        var distortionsStorage: String = ""
        var evidenceFor: String = ""
        var evidenceAgainst: String = ""
        var balancedThought: String = ""
        var intensityBefore: Int = 0
        var intensityAfter: Int = 0
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class ExerciseCompletion {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var exerciseID: String = ""
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var title: String = ""
        var body: String = ""
        var sourceKind: String?
        var sourceID: String?
        var durationSeconds: Int?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class PlannedActivity {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var isDeleted: Bool = false
        var title: String = ""
        var activityDescription: String = ""
        var category: String = "Nourishing"
        var scheduledDate: Date = Date()
        var predictedEnjoyment: Int = 5
        var actualEnjoyment: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var notes: String?

        init() {}
    }

    @Model
    final class AssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var assessmentType: String = ""
        var score: Int = 0
        var scoreValue: Double?

        init() {}
    }

    @Model
    final class PersonalityAssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var opennessScore: Double = 0
        var conscientiousnessScore: Double = 0
        var extraversionScore: Double = 0
        var agreeablenessScore: Double = 0
        var neuroticismScore: Double = 0

        init() {}
    }

    @Model
    final class ProgramProgress {
        var id: UUID = UUID()
        var programID: String = ""
        var completedDays: Int = 0
        var lastCompletedAt: Date?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class FlexibleJournalEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var templateType: String = ""
        var responses: [String] = []

        init() {}
    }

    @Model
    final class MoodCheckIn {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class BreathingSession {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var durationSeconds: Int = 60
        var isDeleted: Bool = false

        init() {}
    }
}

enum CBTVersionedSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        [
            Self.UserSettings.self,
            Self.MoodEntry.self,
            Self.ThoughtRecord.self,
            Self.ExerciseCompletion.self,
            Self.JournalEntry.self,
            Self.PlannedActivity.self,
            Self.AssessmentLog.self,
            Self.PersonalityAssessmentLog.self,
            Self.ProgramProgress.self,
            Self.FlexibleJournalEntry.self,
            Self.MoodCheckIn.self,
            Self.BreathingSession.self,
            Self.SafetyPlan.self
        ]
    }

    @Model
    final class UserSettings {
        var singletonID: String = "default"
        var uuid: UUID? = UUID()
        var hapticsEnabled: Bool? = true
        var currentIcon: String?
        var appLockEnabled: Bool? = false
        var isPremium: Bool? = false

        init() {}
    }

    @Model
    final class MoodEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var emotionsStorage: String = ""
        var notes: String?
        var isDeleted: Bool = false
        var intensity: Int?
        var triggersStorage: String?

        init() {}
    }

    @Model
    final class ThoughtRecord {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var situation: String = ""
        var automaticThought: String = ""
        var emotionsStorage: String = ""
        var distortionsStorage: String = ""
        var evidenceFor: String = ""
        var evidenceAgainst: String = ""
        var balancedThought: String = ""
        var intensityBefore: Int = 0
        var intensityAfter: Int = 0
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class ExerciseCompletion {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var exerciseID: String = ""
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var title: String = ""
        var body: String = ""
        var sourceKind: String?
        var sourceID: String?
        var durationSeconds: Int?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class PlannedActivity {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var isDeleted: Bool = false
        var title: String = ""
        var activityDescription: String = ""
        var category: String = "Nourishing"
        var scheduledDate: Date = Date()
        var predictedEnjoyment: Int = 5
        var actualEnjoyment: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var notes: String?

        init() {}
    }

    @Model
    final class AssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var assessmentType: String = ""
        var score: Int = 0
        var scoreValue: Double?

        init() {}
    }

    @Model
    final class PersonalityAssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var opennessScore: Double = 0
        var conscientiousnessScore: Double = 0
        var extraversionScore: Double = 0
        var agreeablenessScore: Double = 0
        var neuroticismScore: Double = 0

        init() {}
    }

    @Model
    final class ProgramProgress {
        var id: UUID = UUID()
        var programID: String = ""
        var completedDays: Int = 0
        var lastCompletedAt: Date?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class FlexibleJournalEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var templateType: String = ""
        var responses: [String] = []

        init() {}
    }

    @Model
    final class MoodCheckIn {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class BreathingSession {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var durationSeconds: Int = 60
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class SafetyPlan {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var emergencyContactsStorage: String = "[]"
        var personalWarningSignsStorage: String = "[]"
        var copingStrategiesStorage: String = "[]"

        init() {}
    }
}

enum CBTVersionedSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 3, 0)

    static var models: [any PersistentModel.Type] {
        [
            Self.UserSettings.self,
            Self.MoodEntry.self,
            Self.ThoughtRecord.self,
            Self.ExerciseCompletion.self,
            Self.JournalEntry.self,
            Self.PlannedActivity.self,
            Self.AssessmentLog.self,
            Self.PersonalityAssessmentLog.self,
            Self.ProgramProgress.self,
            Self.FlexibleJournalEntry.self,
            Self.MoodCheckIn.self,
            Self.BreathingSession.self,
            Self.SafetyPlan.self,
            Self.LibraryItem.self,
            Self.Course.self,
            Self.Achievement.self
        ]
    }

    @Model
    final class UserSettings {
        var singletonID: String = "default"
        var uuid: UUID? = UUID()
        var hapticsEnabled: Bool? = true
        var currentIcon: String?
        var appLockEnabled: Bool? = false
        var isPremium: Bool? = false

        init() {}
    }

    @Model
    final class MoodEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var emotionsStorage: String = ""
        var notes: String?
        var isDeleted: Bool = false
        var intensity: Int?
        var triggersStorage: String?
        var sensationsStorage: String?
        var contextTagsStorage: String?

        init() {}
    }

    @Model
    final class ThoughtRecord {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var situation: String = ""
        var automaticThought: String = ""
        var emotionsStorage: String = ""
        var distortionsStorage: String = ""
        var evidenceFor: String = ""
        var evidenceAgainst: String = ""
        var balancedThought: String = ""
        var intensityBefore: Int = 0
        var intensityAfter: Int = 0
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class ExerciseCompletion {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var exerciseID: String = ""
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var title: String = ""
        var body: String = ""
        var sourceKind: String?
        var sourceID: String?
        var durationSeconds: Int?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class PlannedActivity {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var isDeleted: Bool = false
        var title: String = ""
        var activityDescription: String = ""
        var category: String = "Nourishing"
        var scheduledDate: Date = Date()
        var predictedEnjoyment: Int = 5
        var actualEnjoyment: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var notes: String?

        init() {}
    }

    @Model
    final class AssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var assessmentType: String = ""
        var score: Int = 0
        var scoreValue: Double?

        init() {}
    }

    @Model
    final class PersonalityAssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var opennessScore: Double = 0
        var conscientiousnessScore: Double = 0
        var extraversionScore: Double = 0
        var agreeablenessScore: Double = 0
        var neuroticismScore: Double = 0

        init() {}
    }

    @Model
    final class ProgramProgress {
        var id: UUID = UUID()
        var programID: String = ""
        var completedDays: Int = 0
        var lastCompletedAt: Date?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class FlexibleJournalEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var templateType: String = ""
        var responses: [String] = []

        init() {}
    }

    @Model
    final class MoodCheckIn {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class BreathingSession {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var durationSeconds: Int = 60
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class SafetyPlan {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var emergencyContactsStorage: String = "[]"
        var personalWarningSignsStorage: String = "[]"
        var copingStrategiesStorage: String = "[]"

        init() {}
    }

    @Model
    final class LibraryItem {
        var id: String = ""
        var title: String = ""
        var category: String = ""
        var contentData: Data = Data()
        var typeRawValue: String = "Exercise"
        var duration: Int = 0

        init() {}
    }

    @Model
    final class Course {
        var id: String = ""
        var title: String = ""
        var itemIDsStorage: String = "[]"
        var completedItemIDsStorage: String = "[]"
        var isCompleted: Bool = false

        init() {}
    }

    @Model
    final class Achievement {
        var id: UUID = UUID()
        var title: String = ""
        var achievementDescription: String = ""
        var imageName: String = ""
        var isUnlocked: Bool = false
        var unlockConditionStorage: String = "StreakCount"
        var createdAt: Date = Date()
        var unlockedAt: Date?

        init() {}
    }
}

enum CBTVersionedSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 4, 0)

    static var models: [any PersistentModel.Type] {
        [
            Self.UserSettings.self,
            Self.MoodEntry.self,
            Self.ThoughtRecord.self,
            Self.ExerciseCompletion.self,
            Self.JournalEntry.self,
            Self.PlannedActivity.self,
            Self.AssessmentLog.self,
            Self.PersonalityAssessmentLog.self,
            Self.ProgramProgress.self,
            Self.FlexibleJournalEntry.self,
            Self.MoodCheckIn.self,
            Self.BreathingSession.self,
            Self.SafetyPlan.self,
            Self.LibraryItem.self,
            Self.Course.self,
            Self.Achievement.self,
            Self.AudioContent.self
        ]
    }

    @Model
    final class UserSettings {
        var singletonID: String = "default"
        var uuid: UUID? = UUID()
        var hapticsEnabled: Bool? = true
        var currentIcon: String?
        var appLockEnabled: Bool? = false
        var isPremium: Bool? = false

        init() {}
    }

    @Model
    final class MoodEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var emotionsStorage: String = ""
        var notes: String?
        var isDeleted: Bool = false
        var intensity: Int?
        var triggersStorage: String?
        var sensationsStorage: String?
        var contextTagsStorage: String?
        var activityTagsStorage: String?

        init() {}
    }

    @Model
    final class ThoughtRecord {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var situation: String = ""
        var automaticThought: String = ""
        var emotionsStorage: String = ""
        var distortionsStorage: String = ""
        var evidenceFor: String = ""
        var evidenceAgainst: String = ""
        var balancedThought: String = ""
        var intensityBefore: Int = 0
        var intensityAfter: Int = 0
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class ExerciseCompletion {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var exerciseID: String = ""
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class JournalEntry {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var title: String = ""
        var body: String = ""
        var sourceKind: String?
        var sourceID: String?
        var durationSeconds: Int?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class PlannedActivity {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var isDeleted: Bool = false
        var title: String = ""
        var activityDescription: String = ""
        var category: String = "Nourishing"
        var scheduledDate: Date = Date()
        var predictedEnjoyment: Int = 5
        var actualEnjoyment: Int?
        var isCompleted: Bool = false
        var completedAt: Date?
        var notes: String?

        init() {}
    }

    @Model
    final class AssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var assessmentType: String = ""
        var score: Int = 0
        var scoreValue: Double?

        init() {}
    }

    @Model
    final class PersonalityAssessmentLog {
        var id: UUID = UUID()
        var date: Date = Date()
        var opennessScore: Double = 0
        var conscientiousnessScore: Double = 0
        var extraversionScore: Double = 0
        var agreeablenessScore: Double = 0
        var neuroticismScore: Double = 0

        init() {}
    }

    @Model
    final class ProgramProgress {
        var id: UUID = UUID()
        var programID: String = ""
        var completedDays: Int = 0
        var lastCompletedAt: Date?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class FlexibleJournalEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var templateType: String = ""
        var responses: [String] = []

        init() {}
    }

    @Model
    final class MoodCheckIn {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var moodScore: Int = 5
        var notes: String?
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class BreathingSession {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var durationSeconds: Int = 60
        var isDeleted: Bool = false

        init() {}
    }

    @Model
    final class SafetyPlan {
        var id: UUID = UUID()
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var emergencyContactsStorage: String = "[]"
        var personalWarningSignsStorage: String = "[]"
        var copingStrategiesStorage: String = "[]"

        init() {}
    }

    @Model
    final class LibraryItem {
        var id: String = ""
        var title: String = ""
        var category: String = ""
        var contentData: Data = Data()
        var typeRawValue: String = "Exercise"
        var duration: Int = 0
        var approachesStorage: String = "[]"
        var topicsStorage: String = "[]"
        var difficulty: String = "Beginner"

        init() {}
    }

    @Model
    final class Course {
        var id: String = ""
        var title: String = ""
        var subtitle: String = ""
        var descriptionText: String = ""
        var approach: String = ""
        var category: String = ""
        var difficulty: String = ""
        var approachesStorage: String = "[]"
        var topicsStorage: String = "[]"
        var format: String = "Course"
        var estimatedTotalDuration: Int = 0
        var lessonCount: Int = 0
        var lessonsData: Data = Data()
        var linkedExerciseIDsStorage: String = "[]"
        var linkedGuidedJournalIDsStorage: String = "[]"
        var finalReflectionPrompt: String?
        var finalReflectionResponse: String?
        var isPremium: Bool = false
        var itemIDsStorage: String = "[]"
        var completedItemIDsStorage: String = "[]"
        var isCompleted: Bool = false
        var completedAt: Date?

        init() {}
    }

    @Model
    final class Achievement {
        var id: UUID = UUID()
        var title: String = ""
        var achievementDescription: String = ""
        var imageName: String = ""
        var isUnlocked: Bool = false
        var unlockConditionStorage: String = "StreakCount"
        var createdAt: Date = Date()
        var unlockedAt: Date?

        init() {}
    }

    @Model
    final class AudioContent {
        var id: String = ""
        var title: String = ""
        var contentDescription: String = ""
        var category: String = ""
        var duration: Int = 0
        var typeRawValue: String = "meditation"
        var localAssetFilename: String = ""
        var transcript: String = ""
        var isPremium: Bool = false
        var isCompleted: Bool = false
        var completedAt: Date?
        var isFavorite: Bool = false

        init() {}
    }
}

enum CBTVersionedSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 5, 0)

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
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self
        ]
    }
}

enum CBTVersionedSchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 6, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self
        ]
    }
}

enum CBTVersionedSchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 7, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self
        ]
    }
}

enum CBTVersionedSchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 8, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self
        ]
    }
}

enum CBTVersionedSchemaV10: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 9, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self,
            PersonalValue.self,
            ValueActionCompletion.self
        ]
    }
}

enum CBTVersionedSchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 10, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self,
            PersonalValue.self,
            ValueActionCompletion.self,
            DailyPlanCompletion.self
        ]
    }
}

enum CBTVersionedSchemaV12: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 11, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self,
            FirstSevenDaysJourney.self,
            PersonalValue.self,
            ValueActionCompletion.self,
            DailyPlanCompletion.self
        ]
    }
}

enum CBTVersionedSchemaV13: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 12, 0)

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
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self,
            FirstSevenDaysJourney.self,
            PersonalValue.self,
            ValueActionCompletion.self,
            DailyPlanCompletion.self,
            HelpfulnessFeedback.self
        ]
    }
}

enum CBTVersionedSchemaV14: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 13, 0)

    static var models: [any PersistentModel.Type] {
        SharedPersistence.currentModelTypes
    }
}
