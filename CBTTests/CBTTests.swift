import XCTest
import SwiftData
@testable import CBT

final class CBTTests: XCTestCase {
    func testAppConfigurationUsesExpectedCloudContainer() {
        XCTAssertEqual(AppConfiguration.cloudKitContainerIdentifier, "iCloud.com.melichan.CBT")
        XCTAssertEqual(AppConfiguration.appGroupIdentifier, "group.com.melichan.CBT")
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
        AudioPlayerService.shared.playMP3(named: "definitely_missing_audio_placeholder.mp3")

        XCTAssertEqual(AudioPlayerService.shared.errorMessage, "Audio file not found.")
        XCTAssertFalse(AudioPlayerService.shared.isPlaying)
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
    func testDailyRecommendationsPrioritizeVeryLowMoodSupport() throws {
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

        XCTAssertEqual(recommendations.first?.type, .safetySupport)
        XCTAssertTrue(recommendations.contains { $0.type == .breathingReset })
        XCTAssertTrue((3...5).contains(recommendations.count))
        XCTAssertTrue(recommendations.allSatisfy { !$0.reason.isEmpty && !$0.destination.deepLink.isEmpty })
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
        try context.save()

        AdvancedDataSettingsViewModel().deleteAllData(mode: .deleteOnly, modelContext: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AssessmentLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProgramProgress>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodCheckIn>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BreathingSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SafetyPlan>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Achievement>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CBT.LibraryItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AudioContent>()).count, 0)
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
