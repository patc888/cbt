import Foundation

enum TriggerCategory: String, CaseIterable, Identifiable, Sendable {
    case work
    case relationships
    case health
    case sleep
    case social
    case money
    case school
    case family
    case bodyImage
    case uncertainty
    case loneliness
    case generalStress

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: return "Work"
        case .relationships: return "Relationships"
        case .health: return "Health"
        case .sleep: return "Sleep"
        case .social: return "Social"
        case .money: return "Money"
        case .school: return "School"
        case .family: return "Family"
        case .bodyImage: return "Body Image"
        case .uncertainty: return "Uncertainty"
        case .loneliness: return "Loneliness"
        case .generalStress: return "General Stress"
        }
    }

    var systemImage: String {
        switch self {
        case .work: return "briefcase.fill"
        case .relationships: return "heart.text.square.fill"
        case .health: return "cross.case.fill"
        case .sleep: return "moon.zzz.fill"
        case .social: return "person.2.fill"
        case .money: return "dollarsign.circle.fill"
        case .school: return "graduationcap.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .bodyImage: return "figure.arms.open"
        case .uncertainty: return "questionmark.circle.fill"
        case .loneliness: return "person.crop.circle.badge.exclamationmark"
        case .generalStress: return "bolt.heart.fill"
        }
    }
}

enum TriggerSourceKind: String, Sendable {
    case checkIn
    case journal
    case thoughtRecord
}

struct TriggerSourceEvent: Sendable {
    let date: Date
    let sourceKind: TriggerSourceKind
    let explicitTags: [String]
    let text: String
    let moodScore: Int?
    let stressScore: Int?

    init(
        date: Date,
        sourceKind: TriggerSourceKind,
        explicitTags: [String] = [],
        text: String = "",
        moodScore: Int? = nil,
        stressScore: Int? = nil
    ) {
        self.date = date
        self.sourceKind = sourceKind
        self.explicitTags = explicitTags
        self.text = text
        self.moodScore = moodScore
        self.stressScore = stressScore
    }
}

enum TriggerToolKind: String, Sendable {
    case libraryItem = "Library"
    case exercise = "Exercise"
    case course = "Course"
    case cbtPath = "CBT Path"
}

struct TriggerToolRecommendation: Identifiable, Hashable, Sendable {
    let id: String
    let kind: TriggerToolKind
    let title: String
    let subtitle: String
    let systemImage: String
    let destinationID: String
}

struct PersonalizedTriggerSummary: Identifiable, Hashable, Sendable {
    let category: TriggerCategory
    let sevenDayCount: Int
    let thirtyDayCount: Int
    let allTimeCount: Int
    let averageMood: Double?
    let averageStress: Double?
    let recommendedTools: [TriggerToolRecommendation]
    let completedTools: [TriggerToolRecommendation]

    var id: TriggerCategory { category }

    func count(for window: TriggerLibraryWindow) -> Int {
        switch window {
        case .sevenDays: return sevenDayCount
        case .thirtyDays: return thirtyDayCount
        case .allTime: return allTimeCount
        }
    }
}

enum TriggerLibraryWindow: String, CaseIterable, Identifiable, Sendable {
    case sevenDays
    case thirtyDays
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .allTime: return "All time"
        }
    }

    var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .allTime: return nil
        }
    }
}

struct TriggerLibrarySnapshot: Sendable {
    let summaries: [PersonalizedTriggerSummary]

    static let empty = TriggerLibrarySnapshot(summaries: [])

    func commonTriggers(for window: TriggerLibraryWindow, limit: Int = 5) -> [PersonalizedTriggerSummary] {
        summaries
            .filter { $0.count(for: window) > 0 }
            .sorted { first, second in
                let firstCount = first.count(for: window)
                let secondCount = second.count(for: window)
                if firstCount == secondCount {
                    return first.category.displayName < second.category.displayName
                }
                return firstCount > secondCount
            }
            .prefix(limit)
            .map { $0 }
    }

    var recentToolRecommendations: [TriggerToolRecommendation] {
        commonTriggers(for: .sevenDays, limit: 3)
            .flatMap(\.recommendedTools)
            .reduce(into: [TriggerToolRecommendation]()) { result, tool in
                if !result.contains(where: { $0.id == tool.id }) {
                    result.append(tool)
                }
            }
            .prefix(4)
            .map { $0 }
    }
}

enum PersonalizedTriggerLibraryService {
    @MainActor
    static func snapshot(
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn],
        thoughtRecords: [ThoughtRecord],
        journalEntries: [JournalEntry],
        flexibleJournalEntries: [FlexibleJournalEntry],
        exerciseCompletions: [ExerciseCompletion],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TriggerLibrarySnapshot {
        snapshot(
            events: moodEntries.map { mood in
                TriggerSourceEvent(
                    date: mood.createdAt,
                    sourceKind: .checkIn,
                    explicitTags: mood.triggers,
                    text: (mood.contextTags + mood.activityTags + [mood.notes ?? ""]).joined(separator: " "),
                    moodScore: mood.moodScore,
                    stressScore: mood.anxietyStressScore ?? mood.intensity
                )
            } + moodCheckIns.map { checkIn in
                TriggerSourceEvent(
                    date: checkIn.createdAt,
                    sourceKind: .checkIn,
                    text: checkIn.notes ?? "",
                    moodScore: checkIn.moodScore
                )
            } + thoughtRecords.map { thought in
                TriggerSourceEvent(
                    date: thought.createdAt,
                    sourceKind: .thoughtRecord,
                    text: [thought.situation, thought.automaticThought].joined(separator: " "),
                    stressScore: thought.intensityBefore > 0 ? max(1, min(10, Int((Double(thought.intensityBefore) / 10.0).rounded()))) : nil
                )
            } + journalEntries.map { journal in
                TriggerSourceEvent(
                    date: journal.createdAt,
                    sourceKind: .journal,
                    text: [journal.title, journal.body].joined(separator: " ")
                )
            } + flexibleJournalEntries.map { journal in
                TriggerSourceEvent(
                    date: journal.date,
                    sourceKind: .journal,
                    text: journal.responses.joined(separator: " ")
                )
            },
            completedToolIDs: Set(exerciseCompletions.map(\.exerciseID)),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func snapshot(
        events: [TriggerSourceEvent],
        completedToolIDs: Set<String>,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TriggerLibrarySnapshot {
        let matchedEvents = events.map { event in
            (event: event, categories: categories(in: event))
        }

        let summaries = TriggerCategory.allCases.compactMap { category -> PersonalizedTriggerSummary? in
            let categoryEvents = matchedEvents
                .filter { $0.categories.contains(category) }
                .map(\.event)
            guard !categoryEvents.isEmpty else { return nil }

            let recommendations = recommendations(for: category)
            let completed = recommendations.filter { completedToolIDs.contains($0.destinationID) }

            return PersonalizedTriggerSummary(
                category: category,
                sevenDayCount: count(categoryEvents, withinDays: 7, referenceDate: referenceDate, calendar: calendar),
                thirtyDayCount: count(categoryEvents, withinDays: 30, referenceDate: referenceDate, calendar: calendar),
                allTimeCount: categoryEvents.count,
                averageMood: average(categoryEvents.compactMap(\.moodScore)),
                averageStress: average(categoryEvents.compactMap(\.stressScore)),
                recommendedTools: recommendations,
                completedTools: completed
            )
        }

        return TriggerLibrarySnapshot(summaries: summaries)
    }

    static func categories(in event: TriggerSourceEvent) -> Set<TriggerCategory> {
        var matches = Set<TriggerCategory>()
        let explicitText = event.explicitTags.joined(separator: " ")
        let allText = ([explicitText, event.text].joined(separator: " ")).lowercased()

        for category in TriggerCategory.allCases where containsKeyword(for: category, in: allText) {
            matches.insert(category)
        }

        if matches.isEmpty && !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            matches.insert(.generalStress)
        }

        return matches
    }

    static func recommendations(for category: TriggerCategory) -> [TriggerToolRecommendation] {
        recommendationMap[category] ?? []
    }

    private static func count(
        _ events: [TriggerSourceEvent],
        withinDays days: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: referenceDate) else {
            return 0
        }
        return events.filter { $0.date >= cutoff && $0.date <= referenceDate }.count
    }

    private static func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func containsKeyword(for category: TriggerCategory, in text: String) -> Bool {
        keywords[category, default: []].contains { keyword in
            text.localizedCaseInsensitiveContains(keyword)
        }
    }

    private static let keywords: [TriggerCategory: [String]] = [
        .work: ["work", "job", "boss", "manager", "coworker", "deadline", "meeting", "email", "shift", "client", "project"],
        .relationships: ["relationship", "partner", "date", "dating", "breakup", "argument", "conflict", "friendship", "boundar"],
        .health: ["health", "doctor", "pain", "illness", "medical", "symptom", "medication", "appointment"],
        .sleep: ["sleep", "insomnia", "tired", "exhausted", "bedtime", "night", "rest", "wake up", "woke"],
        .social: ["social", "party", "group", "people", "conversation", "presentation", "awkward", "judg", "rejection"],
        .money: ["money", "bill", "rent", "debt", "budget", "paycheck", "payment", "finance", "financial", "cost"],
        .school: ["school", "class", "exam", "test", "homework", "study", "grade", "assignment", "teacher", "college"],
        .family: ["family", "parent", "mom", "mother", "dad", "father", "sibling", "child", "kids", "relative"],
        .bodyImage: ["body", "weight", "appearance", "mirror", "shape", "size", "looks", "image", "clothes"],
        .uncertainty: ["uncertain", "uncertainty", "unknown", "what if", "worry", "decision", "choice", "guarantee", "control"],
        .loneliness: ["lonely", "loneliness", "isolated", "alone", "left out", "disconnected", "no one"],
        .generalStress: ["stress", "stressed", "overwhelmed", "pressure", "burnout", "too much", "tense", "busy"]
    ]

    private static let recommendationMap: [TriggerCategory: [TriggerToolRecommendation]] = [
        .work: [
            tool(.exercise, "exercise_001", "Identify the Stressor", "Sort the concrete demand from the story around it."),
            tool(.exercise, "exercise_act_005", "Control vs Influence", "Choose one controllable next step."),
            tool(.cbtPath, "skill_path_stress_at_work", "Stress at Work", "A CBT path for pressure, tasks, and recovery.")
        ],
        .relationships: [
            tool(.exercise, "exercise_010", "Mind Reading Check", "Check assumptions before reacting."),
            tool(.exercise, "exercise_017", "Examine the Evidence", "Look for the whole relationship picture."),
            tool(.course, "course_social_anxiety_support", "Social Anxiety Support", "Tools for connection, assumptions, and experiments.")
        ],
        .health: [
            tool(.exercise, "exercise_003", "5-4-3-2-1 Technique", "Ground attention before problem-solving."),
            tool(.exercise, "exercise_act_005", "Control vs Influence", "Separate useful action from uncertainty."),
            tool(.cbtPath, "skill_path_anxiety_reset", "Anxiety Reset", "A path for worry, body alarm, and steady steps.")
        ],
        .sleep: [
            tool(.exercise, "exercise_016", "Worry Time", "Park worries for a planned window."),
            tool(.exercise, "exercise_028", "4-7-8 Breathing", "Use a simple wind-down breath cue."),
            tool(.cbtPath, "skill_path_sleep_worry", "Sleep & Worry", "A path for winding down loops at night.")
        ],
        .social: [
            tool(.exercise, "exercise_010", "Mind Reading Check", "Hold social guesses more lightly."),
            tool(.exercise, "exercise_032", "Safety Behavior Drop", "Loosen one protective habit gently."),
            tool(.cbtPath, "skill_path_social_anxiety", "Social Anxiety", "A CBT path for small social experiments.")
        ],
        .money: [
            tool(.exercise, "exercise_001", "Identify the Stressor", "Name the specific money pressure."),
            tool(.exercise, "exercise_act_005", "Control vs Influence", "Find one action inside your influence."),
            tool(.exercise, "exercise_031", "Mastery Task", "Complete one small practical step.")
        ],
        .school: [
            tool(.exercise, "exercise_023", "Routine Anchor", "Attach study support to an existing habit."),
            tool(.exercise, "exercise_025", "De-catastrophizing", "Right-size the feared outcome."),
            tool(.course, "course_procrastination_avoidance", "Procrastination and Avoidance", "Start smaller when tasks feel loaded.")
        ],
        .family: [
            tool(.exercise, "exercise_010", "Mind Reading Check", "Check assumptions in family moments."),
            tool(.exercise, "exercise_006", "Inner Friend", "Use kinder self-talk after hard interactions."),
            tool(.exercise, "exercise_act_005", "Control vs Influence", "Choose what is yours to do.")
        ],
        .bodyImage: [
            tool(.exercise, "exercise_018", "Label Reducer", "Replace harsh labels with specific facts."),
            tool(.exercise, "exercise_006", "Inner Friend", "Practice supportive language toward yourself."),
            tool(.cbtPath, "skill_path_self_esteem", "Self-Esteem", "Build evidence, specificity, and self-respect.")
        ],
        .uncertainty: [
            tool(.exercise, "exercise_016", "Worry Time", "Give worry a boundary."),
            tool(.exercise, "exercise_024", "Decatastrophize a Fear", "Check likelihood, coping, and alternatives."),
            tool(.cbtPath, "skill_path_overthinking", "Overthinking", "Turn loops into clearer questions and action.")
        ],
        .loneliness: [
            tool(.exercise, "exercise_015", "Pleasant Activity Scheduling", "Add one small nourishing moment."),
            tool(.exercise, "exercise_act_007", "Committed Action Plan", "Plan one values-based connection step."),
            tool(.cbtPath, "skill_path_low_mood_support", "Low Mood Support", "Gentle activation and kinder self-talk.")
        ],
        .generalStress: [
            tool(.exercise, "exercise_004", "Box Breathing", "Use a quick body reset."),
            tool(.exercise, "exercise_003", "5-4-3-2-1 Technique", "Ground attention in the present."),
            tool(.cbtPath, "skill_path_anxiety_reset", "Anxiety Reset", "A path for worry, body alarm, and next steps.")
        ]
    ]

    private static func tool(
        _ kind: TriggerToolKind,
        _ id: String,
        _ title: String,
        _ subtitle: String
    ) -> TriggerToolRecommendation {
        TriggerToolRecommendation(
            id: "\(kind.rawValue)-\(id)",
            kind: kind,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage(for: kind),
            destinationID: id
        )
    }

    private static func systemImage(for kind: TriggerToolKind) -> String {
        switch kind {
        case .libraryItem: return "books.vertical.fill"
        case .exercise: return "figure.mind.and.body"
        case .course: return "graduationcap.fill"
        case .cbtPath: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}
