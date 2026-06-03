import Foundation
import OSLog
import SwiftData

nonisolated enum ContinueDestination: Hashable {
    case dailyPlan(DailyRecommendationDestination)
    case thoughtRecord(PersistentIdentifier)
    case guidedJournal(kind: String)
    case exercise(exerciseID: String)
    case course(courseID: String)
    case cbtPath(programID: String)
    case assessment(kind: AssessmentKind)
    case activityPlanner

    var identityKey: String {
        switch self {
        case .dailyPlan(let destination):
            return "daily-\(destination.deepLink)"
        case .thoughtRecord(let id):
            return "thought-\(id)"
        case .guidedJournal(let kind):
            return "journal-\(kind)"
        case .exercise(let exerciseID):
            return "exercise-\(exerciseID)"
        case .course(let courseID):
            return "course-\(courseID)"
        case .cbtPath(let programID):
            return "path-\(programID)"
        case .assessment(let kind):
            return "assessment-\(kind.rawValue)"
        case .activityPlanner:
            return "activity-planner"
        }
    }

    var dailyPlanDestinationKey: String? {
        switch self {
        case .dailyPlan(let destination):
            return destination.deepLink
        case .guidedJournal(let kind):
            return DailyRecommendationDestination.guidedJournal(kind: kind).deepLink
        case .exercise(let exerciseID):
            return DailyRecommendationDestination.libraryExercise(exerciseID: exerciseID).deepLink
        case .course(let courseID):
            return DailyRecommendationDestination.course(courseID: courseID).deepLink
        case .cbtPath(let programID):
            return DailyRecommendationDestination.program(programID: programID).deepLink
        case .assessment:
            return DailyRecommendationDestination.assessments.deepLink
        case .activityPlanner:
            return DailyRecommendationDestination.behavioralActivation.deepLink
        case .thoughtRecord:
            return nil
        }
    }
}

nonisolated struct ContinueItem: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let destination: ContinueDestination
    let updatedAt: Date
    let priority: Int
    var progressPercentage: Int? = nil

    var id: String { destination.identityKey }
}

nonisolated struct ContinueItemResolver {
    static let recentDayWindow = 7

    func bestItem(
        from candidates: [ContinueItem],
        fallbackRecommendations: [DailyRecommendation],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ContinueItem? {
        let deduped = dedupe(candidates)
        let cutoff = calendar.date(byAdding: .day, value: -Self.recentDayWindow, to: now) ?? now
        let recent = deduped.filter { $0.updatedAt >= cutoff }
        if let item = ranked(recent.isEmpty ? deduped : recent).first {
            return item
        }

        return fallbackRecommendations
            .filter { !$0.isCompletedToday }
            .sorted { first, second in
                if first.priority == second.priority {
                    return first.title < second.title
                }
                return first.priority > second.priority
            }
            .first
            .map { recommendation in
                ContinueItem(
                    title: recommendation.title,
                    subtitle: recommendation.subtitle,
                    destination: .dailyPlan(recommendation.destination),
                    updatedAt: now,
                    priority: recommendation.priority
                )
            }
    }

    func dedupe(_ items: [ContinueItem]) -> [ContinueItem] {
        var bestByKey = [String: ContinueItem]()
        for item in items {
            guard let existing = bestByKey[item.destination.identityKey] else {
                bestByKey[item.destination.identityKey] = item
                continue
            }

            if item.priority > existing.priority ||
                (item.priority == existing.priority && item.updatedAt > existing.updatedAt) {
                bestByKey[item.destination.identityKey] = item
            }
        }
        return Array(bestByKey.values)
    }

    private func ranked(_ items: [ContinueItem]) -> [ContinueItem] {
        items.sorted { first, second in
            if first.priority == second.priority {
                if first.updatedAt == second.updatedAt {
                    return first.title < second.title
                }
                return first.updatedAt > second.updatedAt
            }
            return first.priority > second.priority
        }
    }
}

@MainActor
struct ContinueItemService {
    static let shared = ContinueItemService()

    private let resolver = ContinueItemResolver()

    func bestItem(
        from context: ModelContext,
        recommendations: [DailyRecommendation],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ContinueItem? {
        resolver.bestItem(
            from: candidates(from: context, now: now, calendar: calendar),
            fallbackRecommendations: recommendations,
            now: now,
            calendar: calendar
        )
    }

    private func candidates(
        from context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [ContinueItem] {
        var items = [ContinueItem]()
        items.append(contentsOf: thoughtRecordCandidates(from: context))
        items.append(contentsOf: guidedJournalCandidates(from: context))
        items.append(contentsOf: courseCandidates(from: context))
        items.append(contentsOf: pathCandidates(from: context))
        items.append(contentsOf: plannedActivityCandidates(from: context, now: now, calendar: calendar))
        items.append(contentsOf: assessmentCandidates(from: context, now: now, calendar: calendar))
        return items
    }

    private func thoughtRecordCandidates(from context: ModelContext) -> [ContinueItem] {
        fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context
        )
        .filter { record in
            record.isDraft ||
                record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (record.mode == .guided && record.evidenceAgainst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .map { record in
            ContinueItem(
                title: "Finish Thought Record",
                subtitle: record.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Complete the reframe you started." : record.situation,
                destination: .thoughtRecord(record.persistentModelID),
                updatedAt: record.updatedAt,
                priority: 96
            )
        }
    }

    private func guidedJournalCandidates(from context: ModelContext) -> [ContinueItem] {
        fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date, order: .reverse)]
            ),
            from: context
        )
        .compactMap { entry -> ContinueItem? in
            guard let template = JournalTemplate.template(matching: entry.templateType),
                  entry.responses.count < template.promptSteps.count
            else {
                return nil
            }

            return ContinueItem(
                title: "Finish \(template.name)",
                subtitle: "\(entry.responses.count) of \(template.promptSteps.count) prompts answered.",
                destination: .guidedJournal(kind: template.id),
                updatedAt: entry.date,
                priority: 88
            )
        }
    }

    private func courseCandidates(from context: ModelContext) -> [ContinueItem] {
        fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.title)]), from: context)
            .filter { course in
                !course.isCompleted && course.progressTotal > 0 && course.completedLessonCount > 0
            }
            .map { course in
                let isSkillPath = course.isSkillPath
                let completedUnit = isSkillPath ? "steps" : "lessons"
                let destination: ContinueDestination = isSkillPath
                    ? .cbtPath(programID: course.id)
                    : .course(courseID: course.id)

                return ContinueItem(
                    title: "Continue \(course.title)",
                    subtitle: "\(isSkillPath ? "Skill Path" : "Course") • \(course.completedLessonCount) of \(course.progressTotal) \(completedUnit) • \(course.progressPercentage)% complete.",
                    destination: destination,
                    updatedAt: course.completedAt ?? Date.distantPast,
                    priority: (isSkillPath ? 88 : 82) + min(course.completedLessonCount, 8),
                    progressPercentage: course.progressPercentage
                )
            }
    }

    private func pathCandidates(from context: ModelContext) -> [ContinueItem] {
        fetch(
            FetchDescriptor<ProgramProgress>(
                predicate: #Predicate<ProgramProgress> { $0.isDeleted == false }
            ),
            from: context
        )
        .compactMap { progress -> ContinueItem? in
            guard progress.programID == CBTProgram.tacklingProcrastination.id,
                  progress.completedDays < CBTProgram.tacklingProcrastination.days.count
            else {
                return nil
            }

            return ContinueItem(
                title: "Continue \(CBTProgram.tacklingProcrastination.title)",
                subtitle: "\(progress.completedDays) of \(CBTProgram.tacklingProcrastination.days.count) days complete.",
                destination: .cbtPath(programID: progress.programID),
                updatedAt: progress.lastCompletedAt ?? Date.distantPast,
                priority: 78 + min(progress.completedDays, 8)
            )
        }
    }

    private func plannedActivityCandidates(
        from context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [ContinueItem] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return fetch(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> { $0.isDeleted == false && $0.isCompleted == false },
                sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
            ),
            from: context
        )
        .filter { $0.scheduledDate < tomorrow }
        .map { activity in
            ContinueItem(
                title: activity.title.isEmpty ? "Complete Planned Activity" : activity.title,
                subtitle: "Reflect on this Daily Plan activity.",
                destination: .activityPlanner,
                updatedAt: max(activity.createdAt, activity.scheduledDate),
                priority: 84
            )
        }
    }

    private func assessmentCandidates(
        from context: ModelContext,
        now: Date,
        calendar: Calendar
    ) -> [ContinueItem] {
        let logs = fetch(
            FetchDescriptor<AssessmentLog>(
                sortBy: [SortDescriptor(\AssessmentLog.date, order: .reverse)]
            ),
            from: context
        )
        let recentKinds = Set(logs.compactMap { AssessmentKind(rawValue: $0.assessmentType) })
        guard let kind = AssessmentKind.validatedTrackers.first(where: { !recentKinds.contains($0) }) else {
            return []
        }

        let latestAssessmentDate = logs.first?.date ?? Date.distantPast
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        guard latestAssessmentDate < thirtyDaysAgo else {
            return []
        }

        return [
            ContinueItem(
                title: "Check In With \(kind.rawValue)",
                subtitle: AssessmentDefinitionCatalog.definition(for: kind).subtitle,
                destination: .assessment(kind: kind),
                updatedAt: latestAssessmentDate,
                priority: 54
            )
        ]
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, from context: ModelContext) -> [T] {
        do {
            var descriptor = descriptor
            descriptor.includePendingChanges = true
            return try context.fetch(descriptor)
        } catch {
            AppLogger.make(category: "ContinueItemService").error("Continue item fetch failed")
            return []
        }
    }
}
