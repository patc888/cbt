import Foundation

enum CBTPlanFocusArea: String, CaseIterable, Identifiable {
    case anxiety = "Anxiety"
    case mood = "Mood"
    case stress = "Stress"
    case mindfulness = "Mindfulness"
    case sleep = "Sleep"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .anxiety: return "Calm the alarm"
        case .mood: return "Rebuild momentum"
        case .stress: return "Lower the load"
        case .mindfulness: return "Notice sooner"
        case .sleep: return "Protect recovery"
        }
    }

    var weeklySkill: String {
        switch self {
        case .anxiety: return "Name the threat thought, then test it gently."
        case .mood: return "Plan one small action before motivation arrives."
        case .stress: return "Sort what is controllable from what needs release."
        case .mindfulness: return "Practice a short pause before responding."
        case .sleep: return "Build a consistent wind-down cue."
        }
    }

    var practiceTargets: [CBTPlanTarget] {
        switch self {
        case .anxiety:
            return [
                CBTPlanTarget(title: "Run one thought record", destination: .journal),
                CBTPlanTarget(title: "Use one body-calming tool", destination: .toolkit),
                CBTPlanTarget(title: "Check GAD-7 this week", destination: .assessments)
            ]
        case .mood:
            return [
                CBTPlanTarget(title: "Schedule one values-based action", destination: .journal),
                CBTPlanTarget(title: "Complete one guided reflection", destination: .journal),
                CBTPlanTarget(title: "Check PHQ-8 this week", destination: .assessments)
            ]
        case .stress:
            return [
                CBTPlanTarget(title: "Try one reset tool", destination: .toolkit),
                CBTPlanTarget(title: "Journal the main pressure point", destination: .journal),
                CBTPlanTarget(title: "Check PSS-4 this week", destination: .assessments)
            ]
        case .mindfulness:
            return [
                CBTPlanTarget(title: "Practice one mindful exercise", destination: .toolkit),
                CBTPlanTarget(title: "Write one noticing note", destination: .journal),
                CBTPlanTarget(title: "Check MAAS-5 this week", destination: .assessments)
            ]
        case .sleep:
            return [
                CBTPlanTarget(title: "Choose one wind-down tool", destination: .toolkit),
                CBTPlanTarget(title: "Journal tomorrow's first step", destination: .journal),
                CBTPlanTarget(title: "Check sleep quality this week", destination: .assessments)
            ]
        }
    }

    var adjustmentPrompt: String {
        switch self {
        case .anxiety:
            return "If alarm thoughts are still running the day, make next week smaller and repeat the body-calming target."
        case .mood:
            return "If energy is low, lower the activation target until it is almost too easy to refuse."
        case .stress:
            return "If pressure is still high, move one commitment out of this week before adding another skill."
        case .mindfulness:
            return "If pauses are hard to remember, attach the practice to one daily transition."
        case .sleep:
            return "If sleep is still erratic, protect one consistent cue before changing the whole routine."
        }
    }
}

enum CBTPlanDestination {
    case assessments
    case toolkit
    case journal
    case insights
}

struct CBTPlanTarget: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let destination: CBTPlanDestination
}

struct CBTPlanSnapshot {
    let focusArea: CBTPlanFocusArea
    let baselineTitle: String
    let baselineDetail: String
    let hasBaseline: Bool
    let weekStart: Date
    let weekEnd: Date
    let weeklyExerciseCount: Int
    let weeklyJournalCount: Int
    let weeklyAssessmentCount: Int
    let reviewCompleted: Bool

    var completedTargetCount: Int {
        [
            weeklyExerciseCount > 0 || weeklyJournalCount > 0,
            weeklyJournalCount > 0,
            weeklyAssessmentCount > 0
        ].filter { $0 }.count
    }
}

enum MyCBTPlanService {
    static func inferredFocusArea(from logs: [AssessmentLog]) -> CBTPlanFocusArea {
        guard let latest = logs.sorted(by: { $0.date > $1.date }).first else {
            return .stress
        }

        switch latest.assessmentType {
        case AssessmentKind.gad7.rawValue,
             AssessmentKind.socialAnxiety.rawValue,
             AssessmentKind.panicSymptoms.rawValue:
            return .anxiety
        case AssessmentKind.phq8.rawValue,
             AssessmentKind.wellBeing.rawValue,
             AssessmentKind.selfCompassion.rawValue:
            return .mood
        case AssessmentKind.pss4.rawValue,
             AssessmentKind.burnout.rawValue,
             AssessmentKind.emotionRegulation.rawValue:
            return .stress
        case AssessmentKind.maas5.rawValue,
             AssessmentKind.adhdAttention.rawValue:
            return .mindfulness
        case AssessmentKind.sleepQuality.rawValue:
            return .sleep
        default:
            return .stress
        }
    }

    static func snapshot(
        focusArea: CBTPlanFocusArea,
        assessmentLogs: [AssessmentLog],
        exerciseCompletions: [ExerciseCompletion],
        flexibleJournalEntries: [FlexibleJournalEntry],
        reviewCompleted: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CBTPlanSnapshot {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: now, duration: 7 * 24 * 60 * 60)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.end
        let latestAssessment = assessmentLogs.sorted(by: { $0.date > $1.date }).first

        let baselineTitle: String
        let baselineDetail: String
        if let latestAssessment {
            baselineTitle = latestAssessment.assessmentType
            baselineDetail = "Latest score \(latestAssessment.score) from \(latestAssessment.date.formatted(date: .abbreviated, time: .omitted))"
        } else {
            baselineTitle = "Baseline needed"
            baselineDetail = "Start with one tracker so the plan has a clear starting point."
        }

        return CBTPlanSnapshot(
            focusArea: focusArea,
            baselineTitle: baselineTitle,
            baselineDetail: baselineDetail,
            hasBaseline: latestAssessment != nil,
            weekStart: week.start,
            weekEnd: weekEnd,
            weeklyExerciseCount: exerciseCompletions.filter { week.contains($0.createdAt) && !$0.isDeleted }.count,
            weeklyJournalCount: flexibleJournalEntries.filter { week.contains($0.date) }.count,
            weeklyAssessmentCount: assessmentLogs.filter { week.contains($0.date) }.count,
            reviewCompleted: reviewCompleted
        )
    }
}
