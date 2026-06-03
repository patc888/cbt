import Foundation
import SwiftData

enum FirstSessionWinKind: String, CaseIterable, Identifiable, Sendable {
    case moodCheckIn
    case breathing
    case todaysPlan
    case existingActivity

    var id: String { rawValue }

    var dailyPlanItem: DailyPlanItem? {
        switch self {
        case .moodCheckIn:
            return .moodCheckIn
        case .breathing:
            return .breathingReset
        case .todaysPlan:
            return .activityPlanner
        case .existingActivity:
            return nil
        }
    }

    var homeTitle: String {
        switch self {
        case .moodCheckIn:
            return String(localized: "First check-in saved")
        case .breathing:
            return String(localized: "First breathing reset saved")
        case .todaysPlan:
            return String(localized: "Today's plan saved")
        case .existingActivity:
            return String(localized: "Your progress is ready")
        }
    }
}

enum FirstSessionWinService {
    static let completedKey = "cbt_firstSessionWinCompleted"
    static let completedKindKey = "cbt_firstSessionWinKind"
    static let completedAtKey = "cbt_firstSessionWinCompletedAt"
    static let reminderOfferedKey = "cbt_firstSessionWinReminderOffered"
    static let reminderOptedInKey = "cbt_firstSessionWinReminderOptedIn"
    static let dailyPlanMarker = "first_session_win_daily_plan"

    static func shouldPresent(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: completedKey)
    }

    @MainActor
    static func shouldPresentAfterExistingUserCheck(
        modelContext: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        if defaults.bool(forKey: completedKey) {
            return false
        }

        if hasExistingActivity(in: modelContext) {
            markCompleted(
                kind: .existingActivity,
                defaults: defaults,
                now: now,
                logEvent: false
            )
            return false
        }

        return true
    }

    @MainActor
    static func complete(
        kind: FirstSessionWinKind,
        modelContext: ModelContext,
        moodScore: Int = 6,
        planTitle: String = "",
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) throws {
        switch kind {
        case .moodCheckIn:
            try upsertMoodCheckIn(
                modelContext: modelContext,
                moodScore: moodScore,
                now: now
            )
        case .breathing:
            modelContext.insert(BreathingSession(createdAt: now, durationSeconds: 60))
        case .todaysPlan:
            try refreshDailyPlan(
                modelContext: modelContext,
                planTitle: planTitle,
                now: now
            )
        case .existingActivity:
            break
        }

        try modelContext.save()
        markCompleted(kind: kind, defaults: defaults, now: now)
    }

    static func skip(defaults: UserDefaults = .standard, now: Date = Date()) {
        LocalEventLog.record(
            "first_session_win_skipped",
            defaults: defaults,
            now: now
        )
    }

    static func completedKind(defaults: UserDefaults = .standard) -> FirstSessionWinKind? {
        guard let rawValue = defaults.string(forKey: completedKindKey) else { return nil }
        return FirstSessionWinKind(rawValue: rawValue)
    }

    static func setTomorrowReminderOptIn(
        _ enabled: Bool,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(true, forKey: reminderOfferedKey)
        defaults.set(enabled, forKey: reminderOptedInKey)

        guard enabled else { return }

        let type = PersonalizedReminderType.dailyMoodCheckIn
        defaults.set(true, forKey: type.enabledDefaultsKey)
        if let hourKey = type.hourDefaultsKey {
            defaults.set(9, forKey: hourKey)
        }
        if let minuteKey = type.minuteDefaultsKey {
            defaults.set(0, forKey: minuteKey)
        }
        defaults.set(TomorrowAnchor.mood.rawValue, forKey: TomorrowAnchor.defaultsKey)
        defaults.set(Date().timeIntervalSince1970, forKey: TomorrowAnchor.updatedAtDefaultsKey)
    }

    @MainActor
    static func scheduleTomorrowReminderIfPossible(defaults: UserDefaults = .standard) async {
        guard defaults.bool(forKey: reminderOptedInKey) else { return }

        let status = await PermissionManager.shared.request(.notifications)
        guard status.isAuthorized else { return }

        try? await PersonalizedReminderService.shared.schedule(
            .dailyMoodCheckIn,
            hour: storedInt(defaults: defaults, key: PersonalizedReminderType.dailyMoodCheckIn.hourDefaultsKey, fallback: 9),
            minute: storedInt(defaults: defaults, key: PersonalizedReminderType.dailyMoodCheckIn.minuteDefaultsKey, fallback: 0)
        )
    }

    @MainActor
    static func hasExistingActivity(in modelContext: ModelContext) -> Bool {
        let moodEntries = count(FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.isDeleted == false }
        ), in: modelContext)
        let moodCheckIns = count(FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false }
        ), in: modelContext)
        let thoughts = count(FetchDescriptor<ThoughtRecord>(
            predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false }
        ), in: modelContext)
        let exercises = count(FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false }
        ), in: modelContext)
        let journals = count(FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { $0.isDeleted == false }
        ), in: modelContext)
        let activities = count(FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> { $0.isDeleted == false }
        ), in: modelContext)
        let breathing = count(FetchDescriptor<BreathingSession>(
            predicate: #Predicate<BreathingSession> { $0.isDeleted == false }
        ), in: modelContext)
        let tinyWins = count(FetchDescriptor<TinyWinCompletion>(
            predicate: #Predicate<TinyWinCompletion> { $0.isDeleted == false }
        ), in: modelContext)

        return moodEntries + moodCheckIns + thoughts + exercises + journals + activities + breathing + tinyWins > 0
    }

    private static func markCompleted(
        kind: FirstSessionWinKind,
        defaults: UserDefaults,
        now: Date,
        logEvent: Bool = true
    ) {
        defaults.set(true, forKey: completedKey)
        defaults.set(kind.rawValue, forKey: completedKindKey)
        defaults.set(now.timeIntervalSince1970, forKey: completedAtKey)

        if logEvent {
            LocalEventLog.record(
                "first_session_win_completed",
                metadata: ["kind": kind.rawValue],
                defaults: defaults,
                now: now
            )
        }
    }

    private static func storedInt(defaults: UserDefaults, key: String?, fallback: Int) -> Int {
        guard let key, let value = defaults.object(forKey: key) as? Int else {
            return fallback
        }

        return value
    }

    @MainActor
    private static func upsertMoodCheckIn(
        modelContext: ModelContext,
        moodScore: Int,
        now: Date
    ) throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let descriptor = FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> {
                $0.isDeleted == false &&
                $0.createdAt >= dayStart &&
                $0.createdAt < dayEnd
            },
            sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.createdAt = now
            existing.moodScore = MoodEntry.clampMoodScore(moodScore)
            existing.notes = existing.notes ?? String(localized: "First session quick check-in.")
        } else {
            modelContext.insert(MoodCheckIn(
                createdAt: now,
                moodScore: MoodEntry.clampMoodScore(moodScore),
                notes: String(localized: "First session quick check-in.")
            ))
        }
    }

    @MainActor
    private static func refreshDailyPlan(
        modelContext: ModelContext,
        planTitle: String,
        now: Date
    ) throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> {
                $0.isDeleted == false &&
                $0.scheduledDate >= dayStart &&
                $0.scheduledDate < dayEnd
            },
            sortBy: [SortDescriptor(\PlannedActivity.createdAt, order: .reverse)]
        )
        let trimmedTitle = planTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? String(localized: "One small step for today") : trimmedTitle
        let existing = try modelContext.fetch(descriptor).first {
            ($0.notes ?? "").contains(dailyPlanMarker)
        }

        if let existing {
            existing.createdAt = now
            existing.title = title
            existing.activityDescription = String(localized: "Created during the first session.")
            existing.scheduledDate = now
            existing.supportedValue = "Courage"
            existing.predictedEnjoyment = 5
            existing.isCompleted = false
            existing.completedAt = nil
            existing.notes = dailyPlanMarker
        } else {
            modelContext.insert(PlannedActivity(
                createdAt: now,
                title: title,
                activityDescription: String(localized: "Created during the first session."),
                category: "Nourishing",
                scheduledDate: now,
                supportedValue: "Courage",
                predictedEnjoyment: 5,
                notes: dailyPlanMarker
            ))
        }
    }

    @MainActor
    private static func count<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in modelContext: ModelContext
    ) -> Int {
        do {
            var descriptor = descriptor
            descriptor.includePendingChanges = false
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
