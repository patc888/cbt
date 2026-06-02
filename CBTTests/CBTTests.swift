import XCTest
import SwiftData
import PDFKit
import SwiftUI
@testable import CBT

final class CBTTests: XCTestCase {
    func testAppConfigurationUsesExpectedCloudContainer() {
        XCTAssertEqual(AppConfiguration.cloudKitContainerIdentifier, "iCloud.com.melichan.CBT")
        XCTAssertEqual(AppConfiguration.appGroupIdentifier, "group.com.melichan.CBT")
    }

    func testCurrentMigrationSchemaCoversAllPersistedModels() {
        let currentModels = Set(CBTVersionedSchemaV6.models.map { String(reflecting: $0) })
        let latestModels = Set(CBTVersionedSchemaV7.models.map { String(reflecting: $0) })
        let expectedModels = Set([
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
        ].map { String(reflecting: $0) })
        let v6Models = expectedModels.subtracting([String(reflecting: ChallengeSession.self)])

        XCTAssertEqual(currentModels, v6Models)
        XCTAssertEqual(latestModels, expectedModels)
        XCTAssertEqual(CBTModelMigrationPlan.schemas.count, 7)
        XCTAssertEqual(CBTModelMigrationPlan.stages.count, 6)
    }

    func testRegisteredDefaultsShowStreakInToolbarOnForFirstLaunch() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppConfiguration.registerUserDefaults(defaults)

        XCTAssertTrue(defaults.bool(forKey: AppConfiguration.showStreakInToolbarKey))
    }

    func testRegisteredDefaultsPreserveSavedStreakToolbarPreference() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: AppConfiguration.showStreakInToolbarKey)

        AppConfiguration.registerUserDefaults(defaults)

        XCTAssertFalse(defaults.bool(forKey: AppConfiguration.showStreakInToolbarKey))
    }

    func testStreakReengagementDailyCheckRunsOnlyOncePerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Self.date(calendar, 2026, 6, 1, 12)
        let sameDay = Self.date(calendar, 2026, 6, 1, 8)
        let previousDay = Self.date(calendar, 2026, 5, 31, 23)

        XCTAssertTrue(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: nil, now: now, calendar: calendar))
        XCTAssertFalse(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: sameDay, now: now, calendar: calendar))
        XCTAssertTrue(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: previousDay, now: now, calendar: calendar))
    }

    func testStreakReengagementThresholdAndNotificationBodies() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertFalse(StreakReengagementNotificationService.hasBeenAwayFor48Hours(
            lastLogin: now.addingTimeInterval(-(48 * 60 * 60) + 1),
            now: now
        ))
        XCTAssertTrue(StreakReengagementNotificationService.hasBeenAwayFor48Hours(
            lastLogin: now.addingTimeInterval(-(48 * 60 * 60)),
            now: now
        ))
        XCTAssertEqual(
            StreakReengagementNotificationService.nextReengagementDate(from: now),
            now.addingTimeInterval(48 * 60 * 60)
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.notificationBody(streakCount: 4),
            "Your 4-day streak can keep going with one 30-second mood check-in."
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.notificationBody(streakCount: 0),
            "A 30-second mood check-in can make it easier to notice your pattern today."
        )
    }

    func testStreakReengagementCurrentStreakMatchesMoodCheckInDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Self.date(calendar, 2026, 6, 1, 12))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let staleDay = calendar.date(byAdding: .day, value: -5, to: today)!

        XCTAssertEqual(
            StreakReengagementNotificationService.currentStreak(
                from: [today, yesterday, twoDaysAgo, staleDay],
                calendar: calendar,
                today: today
            ),
            3
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.currentStreak(
                from: [staleDay],
                calendar: calendar,
                today: today
            ),
            0
        )
    }

    func testThemeModeMapsToExpectedColorScheme() {
        XCTAssertNil(AppTheme.system.colorScheme)
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
    }

    func testPersonalGrowthCalculatorAggregatesConsistencyMilestonesAndEmotionTags() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = Self.date(calendar, 2026, 6, 1, 12)

        let events = try (0..<20).map { index -> PersonalGrowthActivityEvent in
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -index, to: referenceDate))
            let emotions: [String]
            if index < 8 {
                emotions = ["calm"]
            } else if index < 13 {
                emotions = ["anxious"]
            } else if index < 16 {
                emotions = ["hopeful"]
            } else {
                emotions = ["tired"]
            }
            return PersonalGrowthActivityEvent(date: date, emotionTags: emotions)
        }

        let snapshot = PersonalGrowthCalculator.snapshot(
            events: events,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.entriesLastThreeMonths, 20)
        XCTAssertEqual(snapshot.consistencyScore, 29)
        XCTAssertEqual(snapshot.milestones.filter(\.isAchieved).map(\.badgeID), ["growth.entries.5", "growth.entries.20"])
        XCTAssertEqual(UserMilestoneSchema.badgeID(forExactEntryCount: 50), "growth.entries.50")
        XCTAssertEqual(snapshot.topEmotionTags.map(\.name), ["Calm", "Anxious", "Tired"])
        XCTAssertEqual(snapshot.topEmotionTags.map(\.count), [8, 5, 4])
    }

    @MainActor
    func testCBTDataStoreSavesMoodAndThoughtRecords() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        let mood = try context.cbtStore.insertMoodEntry(
            createdAt: createdAt,
            moodScore: 6,
            emotions: ["Calm"],
            triggers: ["Work"],
            sensations: ["Steady"],
            contextTags: ["Home"],
            activityTags: ["Walking"],
            notes: "Saved mood",
            intensity: 4
        )
        let thought = try context.cbtStore.insertThoughtRecord(
            createdAt: createdAt.addingTimeInterval(60),
            situation: "A hard meeting",
            automaticThought: "I will mess it up",
            emotions: ["Anxious"],
            distortions: ["Catastrophizing"],
            evidenceFor: "It is important",
            evidenceAgainst: "I have prepared",
            balancedThought: "I can handle one step",
            intensityBefore: 70,
            intensityAfter: 35
        )

        let savedMood = try XCTUnwrap(try context.fetch(FetchDescriptor<MoodEntry>()).first { $0.id == mood.id })
        XCTAssertEqual(savedMood.notes, "Saved mood")
        XCTAssertEqual(savedMood.activityTags, ["Walking"])

        let savedThought = try XCTUnwrap(try context.fetch(FetchDescriptor<ThoughtRecord>()).first { $0.id == thought.id })
        XCTAssertEqual(savedThought.balancedThought, "I can handle one step")
        XCTAssertEqual(savedThought.intensityAfter, 35)

        let unlockedTitles = Set(try context.fetch(FetchDescriptor<Achievement>())
            .filter(\.isUnlocked)
            .map(\.title))
        XCTAssertTrue(unlockedTitles.contains("Mood Noted"))
        XCTAssertTrue(unlockedTitles.contains("Thought Catcher"))
    }

    func testBundledGuidedJournalTemplatesAreValid() {
        let templates = JournalTemplate.allTemplates
        let expectedTitles: Set<String> = [
            "Worry Unpacker",
            "What Am I Predicting?",
            "Uncertainty Practice",
            "Panic Reflection",
            "Safety Behavior Audit",
            "One Small Step",
            "Low Mood Reflection",
            "Energy vs Mood",
            "Self-Criticism Reframe",
            "Hope Inventory",
            "Inner Critic Dialogue",
            "Strengths Evidence Log",
            "Shame Unpacking",
            "Comparison Detox",
            "Compassionate Letter",
            "Boundary Builder",
            "Conflict Reflection",
            "Needs & Requests",
            "Relationship Trigger Reflection",
            "Repair Conversation Prep",
            "Avoidance Map",
            "Procrastination Unpacker",
            "Task Breakdown",
            "Perfectionism Reframe",
            "Decision Journal",
            "Values Check-In",
            "Control vs Influence",
            "Sleep Wind-Down Reflection",
            "Burnout Check-In",
            "Three Good Things"
        ]

        let bundledTitles = Set(templates.map(\.title))
        let addedTemplates = templates.filter { expectedTitles.contains($0.title) }

        XCTAssertEqual(addedTemplates.count, 30)
        XCTAssertTrue(bundledTitles.isSuperset(of: expectedTitles))
        XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)

        let requestedCategories = [
            "Anxiety",
            "Low Mood",
            "Self-Esteem",
            "Relationships",
            "Productivity",
            "Sleep",
            "Stress & Burnout",
            "Values",
            "Mindfulness",
            "Gratitude"
        ]
        let categories = Set(addedTemplates.map(\.category))
        for category in requestedCategories {
            XCTAssertTrue(categories.contains(category), "Missing category: \(category)")
        }

        for template in addedTemplates {
            XCTAssertFalse(template.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.approach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertGreaterThan(template.estimatedDurationMinutes, 0, template.title)
            XCTAssertTrue((4...7).contains(template.prompts.count), template.title)
            XCTAssertFalse(template.completionMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.tags.isEmpty, template.title)

            for prompt in template.prompts {
                XCTAssertFalse(prompt.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
                XCTAssertFalse(prompt.helperText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, template.title)
            }
        }
    }

    @MainActor
    func testBundledCrashCoursesAreSeededWithRequiredContent() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        try LibraryService.shared.seedLibraryIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        let crashCourses = courses.filter { $0.approach == "Crash Course" }
        let expectedTitles: Set<String> = [
            "Introduction to CBT",
            "Understanding Thoughts, Feelings, and Behaviors",
            "Cognitive Distortions",
            "Thought Reframing Foundations",
            "Anxiety Basics",
            "Panic Attack Toolkit",
            "Depression and Low Mood Basics",
            "Behavioral Activation",
            "Exposure Practice Basics",
            "Social Anxiety Support",
            "Procrastination and Avoidance",
            "Perfectionism",
            "Self-Compassion Basics",
            "Sleep and Worry",
            "Stress and Burnout",
            "Healthy Boundaries",
            "Values and Motivation",
            "Mindfulness Basics",
            "DBT Distress Tolerance Basics",
            "ACT Defusion Basics"
        ]

        XCTAssertEqual(crashCourses.count, 20)
        XCTAssertEqual(Set(crashCourses.map(\.title)), expectedTitles)

        for course in crashCourses {
            XCTAssertEqual(course.lessons.count, 5, course.title)
            XCTAssertEqual(course.lessonCount, 5, course.title)
            XCTAssertGreaterThan(course.estimatedTotalDuration, 0, course.title)
            XCTAssertFalse(course.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
            XCTAssertFalse(course.approaches.isEmpty, course.title)
            XCTAssertFalse(course.completionMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
            XCTAssertFalse(course.finalReflectionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, course.title)
            XCTAssertFalse(course.linkedExerciseIDs.isEmpty && course.linkedGuidedJournalIDs.isEmpty, course.title)

            for lesson in course.lessons {
                XCTAssertFalse(lesson.shortEducationalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
                XCTAssertTrue(lesson.shortEducationalText.contains("Example:"), "\(course.title): \(lesson.title)")
                XCTAssertFalse(lesson.keyTakeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
                XCTAssertFalse(lesson.reflectionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, course.title)
                XCTAssertGreaterThan(lesson.estimatedDuration, 0, course.title)
            }
        }
    }

    @MainActor
    func testDataExportIncludesDailyPlanAndGuidedJournalModels() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(ProgramProgress(programID: "test_program", completedDays: 2))
        context.insert(FlexibleJournalEntry(templateType: "gratitude", responses: ["One", "Two"]))
        context.insert(MoodCheckIn(moodScore: 7, notes: "Settled"))
        context.insert(MoodEntry(
            moodScore: 6,
            sensations: ["tight chest"],
            contextTags: ["Work"],
            activityTags: ["Sleep", "Exercise"]
        ))
        context.insert(BreathingSession(durationSeconds: 180))
        context.insert(SafetyPlan(personalWarningSigns: ["Withdrawing"]))
        let settings = UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true)
        settings.currentIcon = "calm"
        context.insert(settings)
        context.insert(Course(
            id: "course_export",
            title: "Export Course",
            itemIDs: ["lesson_1"],
            completedItemIDs: ["lesson_1"],
            completedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ))
        context.insert(AudioContent(
            id: "audio_export",
            title: "Export Audio",
            description: "A placeholder",
            category: "Grounding",
            duration: 120,
            type: .grounding,
            localAssetFilename: "missing.mp3",
            transcript: "Breathe.",
            isCompleted: true,
            completedAt: Date(timeIntervalSince1970: 1_800_000_100),
            isFavorite: true
        ))
        context.insert(Achievement(
            title: "Export Badge",
            description: "Unlocked in export",
            imageName: "star",
            isUnlocked: true,
            unlockCondition: .moodCheckInCount,
            unlockedAt: Date(timeIntervalSince1970: 1_800_000_200)
        ))
        try context.save()

        let payload = try DataExportService().makePayload(from: context)

        XCTAssertEqual(payload.moodEntries.first?.sensations, ["tight chest"])
        XCTAssertEqual(payload.moodEntries.first?.contextTags, ["Work"])
        XCTAssertEqual(payload.moodEntries.first?.activityTags, ["Sleep", "Exercise"])
        XCTAssertEqual(payload.programProgresses?.count, 1)
        XCTAssertEqual(payload.flexibleJournalEntries?.count, 1)
        XCTAssertEqual(payload.moodCheckIns?.count, 1)
        XCTAssertEqual(payload.breathingSessions?.count, 1)
        XCTAssertEqual(payload.safetyPlans?.count, 1)
        XCTAssertEqual(payload.userSettings?.first?.appLockEnabled, true)
        XCTAssertEqual(payload.courses?.first?.completedItemIDs, ["lesson_1"])
        XCTAssertEqual(payload.audioContents?.first?.isFavorite, true)
        XCTAssertEqual(payload.achievements?.first?.isUnlocked, true)
    }

    @MainActor
    func testDataImportRestoresExpandedUserStateModels() throws {
        let sourceContainer = try SharedPersistence.makeInMemoryModelContainer()
        let sourceContext = ModelContext(sourceContainer)
        let completedAt = Date(timeIntervalSince1970: 1_800_001_000)

        let settings = UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true)
        settings.currentIcon = "calm"
        sourceContext.insert(settings)
        sourceContext.insert(Course(
            id: "course_roundtrip",
            title: "Roundtrip Course",
            itemIDs: ["lesson_1", "lesson_2"],
            completedItemIDs: ["lesson_1", "lesson_2"],
            completedAt: completedAt
        ))
        sourceContext.insert(AudioContent(
            id: "audio_roundtrip",
            title: "Roundtrip Audio",
            description: "A placeholder",
            category: "Grounding",
            duration: 120,
            type: .grounding,
            localAssetFilename: "missing.mp3",
            transcript: "Breathe.",
            isCompleted: true,
            completedAt: completedAt,
            isFavorite: true
        ))
        sourceContext.insert(Achievement(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Roundtrip Badge",
            description: "Unlocked in import",
            imageName: "star",
            isUnlocked: true,
            unlockCondition: .breathingSessionCount,
            createdAt: completedAt,
            unlockedAt: completedAt
        ))
        try sourceContext.save()

        let exportURL = try DataExportService().exportDataFileURL(from: sourceContext)
        let targetContainer = try SharedPersistence.makeInMemoryModelContainer()
        let targetContext = ModelContext(targetContainer)

        try DataImportService().importData(from: exportURL, into: targetContext)

        let importedSettings = try XCTUnwrap(try UserSettings.reconcileSingleton(in: targetContext))
        XCTAssertEqual(importedSettings.appLockEnabled, true)
        XCTAssertEqual(importedSettings.currentIcon, "calm")

        let importedCourse = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Course>()).first)
        XCTAssertEqual(importedCourse.id, "course_roundtrip")
        XCTAssertTrue(importedCourse.isCompleted)
        XCTAssertEqual(importedCourse.completedAt, completedAt)

        let importedAudio = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<AudioContent>()).first)
        XCTAssertEqual(importedAudio.id, "audio_roundtrip")
        XCTAssertTrue(importedAudio.isFavorite)
        XCTAssertTrue(importedAudio.isCompleted)

        let importedAchievement = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Achievement>()).first)
        XCTAssertEqual(importedAchievement.title, "Roundtrip Badge")
        XCTAssertTrue(importedAchievement.isUnlocked)
    }

    @MainActor
    func testMissingAudioPlaceholderReportsErrorWithoutCrashing() {
        AudioPlayerService.shared.stop()
        let didStartPlayback = AudioPlayerService.shared.playMP3(named: "definitely_missing_audio_placeholder.mp3")

        XCTAssertFalse(didStartPlayback)
        XCTAssertNotNil(AudioPlayerService.shared.errorMessage)
        XCTAssertFalse(AudioPlayerService.shared.isPlaying)
        XCTAssertNil(AudioPlayerService.shared.currentFileName)
    }

    @MainActor
    func testClinicalReportAggregatesRecentProgress() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -80, to: now)!, moodScore: 4, intensity: 70))
        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -20, to: now)!, moodScore: 8, intensity: 30))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -10, to: now)!, distortions: ["Catastrophizing", "Mind Reading"], intensityBefore: 80, intensityAfter: 35))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -5, to: now)!, distortions: ["Catastrophizing"], intensityBefore: 60, intensityAfter: 30))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -70, to: now)!, assessmentType: "PHQ-9", score: 12))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -2, to: now)!, assessmentType: "PHQ-9", score: 7))
        try context.save()

        let report = try ClinicalReportGenerator(calendar: calendar).generateReport(from: context)

        XCTAssertEqual(report.windows.count, 3)
        XCTAssertEqual(report.windows.first(where: { $0.days == 30 })?.moodEntryCount, 1)
        XCTAssertEqual(report.windows.first(where: { $0.days == 90 })?.moodEntryCount, 2)
        XCTAssertEqual(report.distortionFrequencies.first?.label, "Catastrophizing")
        XCTAssertEqual(report.distortionFrequencies.first?.count, 2)
        XCTAssertEqual(report.assessmentSummaries.first?.assessmentType, "PHQ-9")
        XCTAssertEqual(report.assessmentSummaries.first?.change, -5)
        XCTAssertEqual(report.moodTrend.lowestScore, 4)
        XCTAssertEqual(report.moodTrend.highestScore, 8)
    }

    @MainActor
    func testDailyRecommendationsPrioritizeVeryLowMoodGrounding() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        context.insert(MoodEntry(
            createdAt: now.addingTimeInterval(-1_800),
            moodScore: 2,
            emotions: ["Anxious"],
            triggers: ["Work"],
            sensations: ["Tight chest"],
            intensity: 9
        ))
        try context.save()

        let recommendations = DailyRecommendationService().recommendations(
            for: now,
            in: context,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(recommendations.first?.type, .breathingReset)
        XCTAssertTrue(recommendations.contains { $0.type == .libraryExercise })
        XCTAssertTrue(recommendations.contains { $0.type == .safetySupport })
        XCTAssertTrue((3...5).contains(recommendations.count))
        XCTAssertTrue(recommendations.allSatisfy { !$0.reason.isEmpty && !$0.destination.deepLink.isEmpty })
    }

    @MainActor
    func testLowMoodSafetyRecommendationIsAvailableWhenUsageGateIsClosed() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        for index in 0..<UsageGate.trialLimit {
            context.insert(MoodEntry(createdAt: Date(timeIntervalSince1970: Double(index)), moodScore: 5))
        }
        try context.save()

        XCTAssertFalse(UsageGate.canCreateNewItem(in: context))

        let plan = DailyRecommendationService().nextStepsAfterMoodCheckIn(for: MoodCheckInRecommendationInput(
            moodScore: 1,
            intensity: 9,
            emotions: ["Hopeless"],
            triggers: [],
            activityTags: [],
            sensations: [],
            contextTags: [],
            notes: nil
        ))

        let safetyStep = try XCTUnwrap(plan.recommendations.first { $0.destination == .safetySupport })
        XCTAssertEqual(safetyStep.type, .safetySupport)
        XCTAssertEqual(safetyStep.destination.deepLink, "cbt://safety-plan")
        XCTAssertNil(safetyStep.completionItem)
    }

    @MainActor
    func testWeeklyReportServiceAggregatesSelectedWeek() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let selectedWeekDate = Self.date(calendar, 2026, 5, 20, 12)

        let firstMoodDate = Self.date(calendar, 2026, 5, 18, 9)
        let secondMoodDate = Self.date(calendar, 2026, 5, 20, 18)
        context.insert(MoodEntry(
            createdAt: firstMoodDate,
            moodScore: 6,
            emotions: ["Calm", "Focused"],
            triggers: ["Work"],
            contextTags: ["Work"],
            activityTags: ["Walking"]
        ))
        context.insert(MoodCheckIn(createdAt: firstMoodDate.addingTimeInterval(30), moodScore: 6))
        context.insert(MoodEntry(
            createdAt: secondMoodDate,
            moodScore: 8,
            emotions: ["Calm"],
            triggers: ["Sleep"],
            activityTags: ["Walking"]
        ))
        context.insert(MoodCheckIn(createdAt: Self.date(calendar, 2026, 5, 22, 8), moodScore: 7))
        context.insert(MoodEntry(createdAt: Self.date(calendar, 2026, 5, 12, 10), moodScore: 5))

        context.insert(ThoughtRecord(
            createdAt: Self.date(calendar, 2026, 5, 19, 13),
            emotions: ["Anxious"],
            distortions: ["Catastrophizing"],
            intensityBefore: 70,
            intensityAfter: 40
        ))
        context.insert(ThoughtRecord(
            createdAt: Self.date(calendar, 2026, 5, 21, 16),
            distortions: ["Catastrophizing", "Mind Reading"],
            intensityBefore: 60,
            intensityAfter: 30
        ))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 18, 12), exerciseID: "box_breathing"))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 23, 12), exerciseID: "thought_record"))
        context.insert(BreathingSession(createdAt: Self.date(calendar, 2026, 5, 18, 20), durationSeconds: 180))
        context.insert(FlexibleJournalEntry(date: Self.date(calendar, 2026, 5, 20, 21), templateType: "gratitude", responses: ["One"]))
        context.insert(FlexibleJournalEntry(date: Self.date(calendar, 2026, 5, 22, 21), templateType: "values", responses: ["Two"]))
        context.insert(PlannedActivity(
            createdAt: Self.date(calendar, 2026, 5, 18, 8),
            title: "Walk",
            category: "Physical",
            scheduledDate: Self.date(calendar, 2026, 5, 21, 9),
            isCompleted: true,
            completedAt: Self.date(calendar, 2026, 5, 21, 10)
        ))
        context.insert(PlannedActivity(
            createdAt: Self.date(calendar, 2026, 5, 18, 8),
            title: "Read",
            scheduledDate: Self.date(calendar, 2026, 5, 22, 9),
            isCompleted: false
        ))
        context.insert(AssessmentLog(date: Self.date(calendar, 2026, 5, 1, 9), assessmentType: "PHQ-9", score: 10))
        context.insert(AssessmentLog(date: Self.date(calendar, 2026, 5, 19, 9), assessmentType: "PHQ-9", score: 8))
        context.insert(Achievement(
            title: "Thought Catcher",
            description: "Completed thought records",
            imageName: "brain.head.profile",
            isUnlocked: true,
            unlockCondition: .thoughtRecordsCount,
            unlockedAt: Self.date(calendar, 2026, 5, 20, 10)
        ))
        try context.save()

        let report = try WeeklyReportService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 5, 24, 12) }
        )
        .generateReport(forWeekContaining: selectedWeekDate, from: context)

        XCTAssertEqual(report.weekStart, Self.date(calendar, 2026, 5, 18, 0))
        XCTAssertEqual(report.weekEnd, Self.date(calendar, 2026, 5, 25, 0))
        XCTAssertEqual(report.moodCheckInCount, 3)
        XCTAssertEqual(report.averageMood ?? 0, 7.0, accuracy: 0.001)
        XCTAssertEqual(report.moodTrend.direction, .higher)
        XCTAssertEqual(report.moodTrend.change ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(report.mostCommonEmotions.first?.label, "Calm")
        XCTAssertEqual(report.mostCommonEmotions.first?.count, 2)
        XCTAssertEqual(report.mostCommonTriggers.first?.label, "Sleep")
        XCTAssertEqual(report.mostCommonActivityTags.first?.label, "Walking")
        XCTAssertEqual(report.mostCommonActivityTags.first?.count, 2)
        XCTAssertEqual(report.thoughtRecordCount, 2)
        XCTAssertEqual(report.mostCommonCognitiveDistortions.first?.label, "Catastrophizing")
        XCTAssertEqual(report.mostCommonCognitiveDistortions.first?.count, 2)
        XCTAssertEqual(report.exercisesCompleted, 2)
        XCTAssertEqual(report.breathingSessionsCompleted, 1)
        XCTAssertEqual(report.guidedJournalsCompleted, 2)
        XCTAssertEqual(report.plannedActivitiesCompleted, 1)
        XCTAssertEqual(report.assessmentChanges.first?.assessmentType, "PHQ-9")
        XCTAssertEqual(report.assessmentChanges.first?.change ?? 0, -2.0, accuracy: 0.001)
        XCTAssertEqual(report.achievementsUnlocked.first?.title, "Thought Catcher")
    }

    @MainActor
    func testWeeklyReportServiceHandlesInsufficientDataGracefully() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar

        let report = try WeeklyReportService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 5, 24, 12) }
        )
        .generateReport(forWeekContaining: Self.date(calendar, 2026, 5, 20, 12), from: context)

        XCTAssertFalse(report.hasAnyData)
        XCTAssertNil(report.averageMood)
        XCTAssertEqual(report.moodTrend.direction, .unavailable)
        XCTAssertEqual(report.moodCheckInCount, 0)
        XCTAssertTrue(report.insufficientDataMessages.contains("No mood check-ins were recorded for this week."))
        XCTAssertTrue(report.suggestedFocusForNextWeek.contains("mood check-ins"))
    }

    @MainActor
    func testWeeklyPDFReportDefaultsToSummaryOnlyWithoutPrivateExcerpts() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let weekStart = Self.date(calendar, 2026, 5, 18, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: weekStart)

        let report = try WeeklyReportGenerator(calendar: calendar).generateReport(
            from: context,
            weekStart: weekStart,
            includeExcerpts: false
        )

        XCTAssertFalse(report.includesExcerpts)
        XCTAssertEqual(report.moodSummary.recordCount, 2)
        XCTAssertEqual(report.triggerSummary.first?.label, "Work")
        XCTAssertEqual(report.activityPatternSummary.activityTagSummary.first?.label, "Walking")
        XCTAssertEqual(report.thoughtRecordSummary.recordCount, 1)
        XCTAssertEqual(report.breathingJournalSummary.breathingSessionCount, 1)
        XCTAssertEqual(report.breathingJournalSummary.journalEntryCount, 1)
        XCTAssertEqual(report.activityPatternSummary.completedPlannedActivities, 1)
        XCTAssertTrue(report.thoughtExcerpts.isEmpty)
        XCTAssertTrue(report.journalExcerpts.isEmpty)
    }

    @MainActor
    func testWeeklyPDFReportIncludesJournalAndThoughtExcerptsWhenExplicitlyRequested() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let weekStart = Self.date(calendar, 2026, 5, 18, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: weekStart)

        let report = try WeeklyReportGenerator(calendar: calendar).generateReport(
            from: context,
            weekStart: weekStart,
            includeExcerpts: true
        )

        XCTAssertTrue(report.includesExcerpts)
        XCTAssertTrue(report.thoughtExcerpts.contains { $0.body.contains("private automatic thought") })
        XCTAssertTrue(report.journalExcerpts.contains { $0.body.contains("private journal body") })
    }

    @MainActor
    func testWeeklyPDFExportWritesEmptyAndPopulatedReports() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let generator = WeeklyReportGenerator(calendar: calendar)
        let emptyWeekStart = Self.date(calendar, 2026, 5, 18, 0)
        let populatedWeekStart = Self.date(calendar, 2026, 5, 25, 0)

        let emptyURL = try generator.generatePDFURL(from: context, weekStart: emptyWeekStart)
        defer { try? FileManager.default.removeItem(at: emptyURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: emptyURL.path))
        XCTAssertGreaterThan((try Data(contentsOf: emptyURL)).count, 0)
        XCTAssertGreaterThan(PDFDocument(url: emptyURL)?.pageCount ?? 0, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: populatedWeekStart)

        let populatedURL = try generator.generatePDFURL(from: context, weekStart: populatedWeekStart)
        defer { try? FileManager.default.removeItem(at: populatedURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: populatedURL.path))
        XCTAssertGreaterThan((try Data(contentsOf: populatedURL)).count, 0)
        XCTAssertGreaterThan(PDFDocument(url: populatedURL)?.pageCount ?? 0, 0)
    }

    @MainActor
    func testMonthlyBadgeProgressAggregatesCurrentMonth() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar

        let checkInDates = [
            Self.date(calendar, 2026, 5, 1, 9),
            Self.date(calendar, 2026, 5, 4, 9),
            Self.date(calendar, 2026, 5, 11, 9),
            Self.date(calendar, 2026, 5, 18, 9),
            Self.date(calendar, 2026, 5, 25, 9)
        ]
        for date in checkInDates {
            context.insert(MoodEntry(createdAt: date, moodScore: 6))
        }
        context.insert(MoodCheckIn(createdAt: checkInDates[0].addingTimeInterval(30), moodScore: 6))

        context.insert(ThoughtRecord(createdAt: Self.date(calendar, 2026, 5, 6, 10), distortions: ["Catastrophizing"], intensityBefore: 70, intensityAfter: 30))
        context.insert(ThoughtRecord(createdAt: Self.date(calendar, 2026, 5, 7, 10), distortions: ["Mind Reading"], intensityBefore: 60, intensityAfter: 35))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 8, 12), exerciseID: "thought_record"))
        context.insert(JournalEntry(createdAt: Self.date(calendar, 2026, 5, 9, 20), title: "Reflection", body: "A note"))
        context.insert(BreathingSession(createdAt: Self.date(calendar, 2026, 5, 10, 8), durationSeconds: 180))
        context.insert(Course(
            title: "Practice Path",
            itemIDs: ["lesson-1"],
            completedItemIDs: ["lesson-1"],
            completedAt: Self.date(calendar, 2026, 5, 20, 14)
        ))
        context.insert(MoodEntry(createdAt: Self.date(calendar, 2026, 4, 30, 9), moodScore: 5))
        try context.save()

        let progress = try AchievementService.shared.monthlyBadgeProgress(
            in: context,
            for: Self.date(calendar, 2026, 5, 31, 12),
            calendar: calendar
        )

        let weekly = try XCTUnwrap(progress.badges.first { $0.kind == .weeklyCheckIns })
        XCTAssertEqual(weekly.currentValue, 5)
        XCTAssertEqual(weekly.targetValue, 5)
        XCTAssertTrue(weekly.isComplete)

        let activities = try XCTUnwrap(progress.badges.first { $0.kind == .wellnessActivities })
        XCTAssertEqual(activities.currentValue, 10)
        XCTAssertTrue(activities.isComplete)

        let course = try XCTUnwrap(progress.badges.first { $0.kind == .courseCompletion })
        XCTAssertEqual(course.currentValue, 1)
        XCTAssertTrue(course.isComplete)

        let tools = try XCTUnwrap(progress.badges.first { $0.kind == .toolVariety })
        XCTAssertEqual(tools.currentValue, 5)
        XCTAssertTrue(tools.isComplete)
    }

    func testCourseCompletionTimestampIsSetWhenFinalItemCompletes() {
        let calendar = Self.weeklyReportCalendar
        let completedAt = Self.date(calendar, 2026, 5, 20, 14)
        let later = Self.date(calendar, 2026, 5, 21, 14)
        let course = Course(title: "Practice Path", itemIDs: ["lesson-1", "lesson-2"], completedItemIDs: ["lesson-1"])

        XCTAssertFalse(course.isCompleted)
        XCTAssertNil(course.completedAt)

        course.markCompleted(itemID: "lesson-2", completedAt: completedAt)

        XCTAssertTrue(course.isCompleted)
        XCTAssertEqual(course.completedAt, completedAt)

        course.markCompleted(itemID: "lesson-2", completedAt: later)
        XCTAssertEqual(course.completedAt, completedAt)
    }

    @MainActor
    func testLibrarySeedIsIdempotentAndDeduplicatesCatalogContent() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        try LibraryService.shared.seedLibraryIfNeeded(in: context)
        let firstItemCount = try context.fetch(FetchDescriptor<CBT.LibraryItem>()).count
        let firstCourseCount = try context.fetch(FetchDescriptor<Course>()).count
        let firstAudioCount = try context.fetch(FetchDescriptor<AudioContent>()).count

        try LibraryService.shared.seedLibraryIfNeeded(in: context)
        let items = try context.fetch(FetchDescriptor<CBT.LibraryItem>())
        let courses = try context.fetch(FetchDescriptor<Course>())
        let audio = try context.fetch(FetchDescriptor<AudioContent>())

        XCTAssertEqual(items.count, firstItemCount)
        XCTAssertEqual(courses.count, firstCourseCount)
        XCTAssertEqual(audio.count, firstAudioCount)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        XCTAssertEqual(Set(courses.map(\.id)).count, courses.count)
        XCTAssertEqual(Set(audio.map(\.id)).count, audio.count)
    }

    @MainActor
    func testBundledPlaceholderAudioCatalogIncludesRequestedItems() throws {
        let expectedAudio: [String: (asset: String, type: AudioContentType, duration: Int)] = [
            "1-Minute Reset": ("1-minute-reset.mp3", .meditation, 1),
            "3-Minute Breathing Space": ("3-minute-breathing-space.mp3", .breathwork, 3),
            "5-Minute Grounding": ("5-minute-grounding.mp3", .grounding, 5),
            "Body Scan": ("body-scan.mp3", .meditation, 10),
            "Sleep Wind-Down": ("sleep-wind-down.mp3", .sleep, 12),
            "Self-Compassion Pause": ("self-compassion-pause.mp3", .meditation, 4),
            "Anxiety Calming Practice": ("anxiety-calming-practice.mp3", .meditation, 8),
            "Rain Soundscape": ("rain-soundscape.mp3", .soundscape, 20),
            "Ocean Soundscape": ("ocean-soundscape.mp3", .soundscape, 20),
            "Brown Noise": ("brown-noise.mp3", .soundscape, 30),
            "Forest Soundscape": ("forest-soundscape.mp3", .soundscape, 20),
            "Focus Ambient Loop": ("focus-ambient-loop.mp3", .soundscape, 25)
        ]

        let catalogByTitle = Dictionary(
            uniqueKeysWithValues: LibraryService.shared.bundledAudioContent.map { ($0.title, $0) }
        )

        for (title, expected) in expectedAudio {
            let audio = try XCTUnwrap(catalogByTitle[title], "Missing audio seed: \(title)")
            XCTAssertEqual(audio.localAssetFilename, expected.asset, title)
            XCTAssertEqual(audio.type, expected.type, title)
            XCTAssertEqual(audio.duration, expected.duration, title)
            XCTAssertFalse(audio.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title)
            XCTAssertFalse(audio.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title)
            XCTAssertFalse(audio.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title)
            XCTAssertFalse(audio.displayTags.isEmpty, title)
        }

        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        try LibraryService.shared.seedLibraryIfNeeded(in: context)

        let audioItems = try context.fetch(FetchDescriptor<CBT.LibraryItem>())
            .filter { $0.type == .audio }
        let seededTitles = Set(audioItems.map(\.title))

        XCTAssertTrue(seededTitles.isSuperset(of: Set(expectedAudio.keys)))
    }

    @MainActor
    func testDeleteAllDataClearsExpandedModelSet() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(MoodEntry(moodScore: 5))
        context.insert(ThoughtRecord(situation: "test", intensityBefore: 50, intensityAfter: 30))
        context.insert(ExerciseCompletion(exerciseID: "exercise_001"))
        context.insert(JournalEntry(title: "Journal", body: "Body"))
        context.insert(PlannedActivity(title: "Walk", scheduledDate: Date()))
        context.insert(AssessmentLog(assessmentType: "PHQ-8", score: 6))
        context.insert(PersonalityAssessmentLog(opennessScore: 1, conscientiousnessScore: 1, extraversionScore: 1, agreeablenessScore: 1, neuroticismScore: 1))
        context.insert(ProgramProgress(programID: "program", completedDays: 1))
        context.insert(FlexibleJournalEntry(templateType: "gratitude", responses: ["One"]))
        context.insert(MoodCheckIn(moodScore: 5))
        context.insert(BreathingSession(durationSeconds: 60))
        context.insert(SafetyPlan(personalWarningSigns: ["Withdrawing"]))
        context.insert(Achievement(title: "Badge", description: "Desc", imageName: "star", unlockCondition: .moodCheckInCount))
        context.insert(CBT.LibraryItem(id: "item", title: "Item", category: "CBT", type: .exercise, duration: 1))
        context.insert(Course(id: "course", title: "Course", itemIDs: ["lesson"]))
        context.insert(AudioContent(id: "audio", title: "Audio", description: "Desc", category: "Grounding", duration: 1, type: .grounding, localAssetFilename: "missing.mp3", transcript: ""))
        context.insert(UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true))
        try context.save()

        AdvancedDataSettingsViewModel().deleteAllData(mode: .deleteOnly, modelContext: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseCompletion>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedActivity>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AssessmentLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalityAssessmentLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProgramProgress>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FlexibleJournalEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodCheckIn>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BreathingSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SafetyPlan>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Achievement>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CBT.LibraryItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AudioContent>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserSettings>()).count, 0)
    }

    func testResetLocalPreferencesClearsUserDefaultsBackedState() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let keys = [
            "cbt_onboardingCompleted",
            "cbt_dailyPlanGoalIDs",
            "appColorTheme",
            "appLockEnabled",
            "cbt_moodReminderEnabled",
            "cbt_moodReminderHour",
            "cbt_home_lastOpenedAt",
            "cbt.achievements.weeklyReportViewed",
            "affirmation_favorites_v1",
            AppConfiguration.showStreakInToolbarKey
        ]

        for key in keys {
            defaults.set("saved", forKey: key)
        }

        DataResetManager.shared.resetLocalPreferences(defaults)

        for key in keys {
            XCTAssertNil(defaults.object(forKey: key), "Expected reset to clear \(key)")
        }
    }

    @MainActor
    func testAchievementServiceSeedsRequiredRewards() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let titles = Set(achievements.map(\.title))
        let requiredTitles: Set<String> = [
            "First Step",
            "Practice Builder",
            "Thought Catcher",
            "Pattern Spotter",
            "Three-Day Flame",
            "Steady Week",
            "Mood Noted",
            "Mood Mapper",
            "Mood Explorer",
            "First Reflection",
            "Reflection Rhythm",
            "First Reset",
            "Breath Companion",
            "Course Opener",
            "Learning Path",
            "Week in View",
            "Intentional Action",
            "Activity Explorer",
            "Self-Check",
            "Four-Week Anchor",
            "Skill Sampler"
        ]

        XCTAssertTrue(titles.isSuperset(of: requiredTitles))
    }

    @MainActor
    func testAchievementServiceUnlocksRequiredRewardsFromProgress() throws {
        UserDefaults.standard.removeObject(forKey: "cbt.achievements.weeklyReportViewed")
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let baseDate = Self.date(calendar, 2026, 5, 24, 9)

        for offset in 0..<30 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: baseDate))
            context.insert(MoodEntry(createdAt: date, moodScore: 6))
        }

        for index in 0..<10 {
            let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: index, to: baseDate))
            context.insert(FlexibleJournalEntry(date: date, templateType: "gratitude", responses: ["One thing"]))
            context.insert(BreathingSession(createdAt: date, durationSeconds: 120))
            context.insert(PlannedActivity(
                createdAt: date,
                title: "Activity \(index)",
                scheduledDate: date,
                isCompleted: true,
                completedAt: date
            ))
        }

        for index in 0..<5 {
            let lessonID = "lesson-\(index)"
            context.insert(Course(
                title: "Course \(index)",
                itemIDs: [lessonID],
                completedItemIDs: [lessonID],
                completedAt: baseDate
            ))
        }

        context.insert(AssessmentLog(date: baseDate, assessmentType: "PHQ-9", score: 8))

        for exerciseID in ["exercise_001", "exercise_dbt_001", "exercise_act_001", "exercise_mindfulness_001"] {
            context.insert(ExerciseCompletion(createdAt: baseDate, exerciseID: exerciseID))
        }

        try context.save()
        AchievementService.shared.recordWeeklyReportViewed(in: context)
        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let unlockedTitles = Set(achievements.filter(\.isUnlocked).map(\.title))
        let expectedUnlocked: Set<String> = [
            "Mood Noted",
            "Mood Mapper",
            "Mood Explorer",
            "First Reflection",
            "Reflection Rhythm",
            "First Reset",
            "Breath Companion",
            "Course Opener",
            "Learning Path",
            "Week in View",
            "Intentional Action",
            "Activity Explorer",
            "Self-Check",
            "Four-Week Anchor",
            "Skill Sampler"
        ]

        XCTAssertTrue(unlockedTitles.isSuperset(of: expectedUnlocked))

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Mood Explorer"]?.completedValue, 30)
        XCTAssertEqual(progress["Skill Sampler"]?.completedValue, 4)
    }

    @MainActor
    func testAchievementMoodProgressDeduplicatesCurrentCheckInPairAndCountsLegacyEntries() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)
        let pairedDate = legacyDate.addingTimeInterval(86_400)

        context.insert(MoodEntry(createdAt: legacyDate, moodScore: 5))
        context.insert(MoodEntry(createdAt: pairedDate, moodScore: 6))
        context.insert(MoodCheckIn(createdAt: pairedDate, moodScore: 6))
        try context.save()

        AchievementService.shared.evaluateAchievements(in: context)

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Mood Mapper"]?.completedValue, 2)
    }

    @MainActor
    func testAchievementStreakProgressUsesHistoricalBestRun() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let oldDate = Self.date(calendar, 2026, 1, 6, 9)

        for offset in 0..<3 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: oldDate))
            context.insert(BreathingSession(createdAt: date, durationSeconds: 120))
        }
        try context.save()

        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let threeDay = try XCTUnwrap(achievements.first { $0.title == "Three-Day Flame" })
        XCTAssertTrue(threeDay.isUnlocked)

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Steady Week"]?.completedValue, 3)
    }

    private static var weeklyReportCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @MainActor
    private func seedWeeklyPDFReportData(
        in context: ModelContext,
        calendar: Calendar,
        weekStart: Date
    ) throws {
        let dayOne = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: weekStart))
        let dayTwo = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: weekStart))
        let outsideWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: weekStart))

        context.insert(MoodEntry(
            createdAt: dayOne,
            moodScore: 4,
            emotions: ["Anxious"],
            triggers: ["Work"],
            activityTags: ["Walking"],
            notes: "private mood note",
            intensity: 80
        ))
        context.insert(MoodCheckIn(createdAt: dayTwo, moodScore: 6, notes: "private quick note"))
        context.insert(MoodEntry(createdAt: outsideWeek, moodScore: 1, emotions: ["Sad"], triggers: ["Outside"], intensity: 90))
        context.insert(ThoughtRecord(
            createdAt: dayOne,
            situation: "private situation",
            automaticThought: "private automatic thought",
            emotions: ["Worried"],
            distortions: ["Catastrophizing"],
            balancedThought: "private balanced thought",
            intensityBefore: 80,
            intensityAfter: 60
        ))
        context.insert(JournalEntry(
            createdAt: dayTwo,
            title: "Private Journal",
            body: "private journal body"
        ))
        context.insert(FlexibleJournalEntry(
            date: dayTwo,
            templateType: "gratitude",
            responses: ["private guided response"]
        ))
        context.insert(BreathingSession(createdAt: dayTwo, durationSeconds: 120))
        context.insert(PlannedActivity(
            createdAt: dayOne,
            title: "Walk",
            category: "Physical",
            scheduledDate: dayOne,
            actualEnjoyment: 8,
            isCompleted: true,
            completedAt: dayTwo
        ))
        try context.save()
    }
}
