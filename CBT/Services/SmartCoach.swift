import Foundation

struct SmartCoachPlan: Hashable {
    let headline: String
    let subtitle: String
    let recommendations: [SmartCoachRecommendation]
}

struct SmartCoachRecommendation: Identifiable, Hashable {
    enum Kind: Hashable {
        case breathingReset
        case distortionLesson(distortion: String)
        case selfCompassionExercise(exerciseID: String)
        case guidedJournal
        case saveHelpfulReframe
        case scheduleReReview
        case beliefCheckIn
        case behavioralExperiment(exerciseID: String)
        case relapsePattern
        case favoriteBySituation
        case reviewLater
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let icon: String

    var id: Kind { kind }
}

enum SmartCoach {
    static func nextSteps(for record: ThoughtRecord) -> SmartCoachPlan {
        let recommendations = recommendations(for: record)

        return SmartCoachPlan(
            headline: "Nice work noticing this",
            subtitle: "You can stop here, or choose one small next step.",
            recommendations: recommendations
        )
    }

    private static func recommendations(for record: ThoughtRecord) -> [SmartCoachRecommendation] {
        var items: [SmartCoachRecommendation] = []

        if record.intensityAfter >= 45 || record.intensityBefore >= 65 {
            items.append(.breathingReset)
        }

        if !record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if record.isReframeFollowUpDue() {
                items.append(.beliefCheckIn)
            } else if !record.isSavedReframe {
                items.append(.saveHelpfulReframe)
            } else if record.reviewDueAt == nil && record.balancedThoughtBeliefLater == nil {
                items.append(.scheduleReReview)
            }
        }

        if shouldRecommendBehavioralExperiment(for: record) {
            items.append(.behavioralExperiment)
        }

        if let distortion = relatedDistortion(from: record.distortions) {
            items.append(.distortionLesson(distortion))
        }

        if shouldRecommendSelfCompassion(for: record) {
            items.append(.selfCompassionExercise)
        }

        if shouldRecommendGuidedJournal(for: record) {
            items.append(.guidedJournal)
        }

        if shouldRecommendRelapsePattern(for: record) {
            items.append(.relapsePattern)
        }

        if record.isSavedReframe && !record.isFavoriteReframe && !record.followUpSituationLabel.isEmpty {
            items.append(.favoriteBySituation)
        }

        items.append(.reviewLater)

        return Array(items.prefix(5))
    }

    private static func relatedDistortion(from distortions: [String]) -> String? {
        let knownDistortions = [
            "All-or-Nothing Thinking",
            "Catastrophizing",
            "Comparison / Unfair Standards",
            "Discounting the Positive",
            "Emotional Reasoning",
            "Fortune Telling",
            "Labeling",
            "Magnification/Minimization",
            "Mental Filter",
            "Mind Reading",
            "Overgeneralization",
            "Personalization",
            "Should Statements"
        ]

        for distortion in distortions {
            let normalized = normalize(distortion)
            if let match = knownDistortions.first(where: { normalize($0) == normalized }) {
                return match
            }
        }

        return distortions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func shouldRecommendSelfCompassion(for record: ThoughtRecord) -> Bool {
        let selfCriticalDistortions = ["Labeling", "Should Statements", "Personalization", "Discounting the Positive"]
        let hasSelfCriticalDistortion = record.distortions.contains { distortion in
            selfCriticalDistortions.contains { normalize($0) == normalize(distortion) }
        }

        let hasSelfCriticalLanguage = containsAnyKeyword(
            in: [record.automaticThought, record.balancedThought] + record.emotions,
            keywords: ["guilty", "embarrassed", "ashamed", "failure", "my fault", "i am bad", "i'm bad", "not good enough"]
        )

        return hasSelfCriticalDistortion || hasSelfCriticalLanguage
    }

    private static func shouldRecommendGuidedJournal(for record: ThoughtRecord) -> Bool {
        let journalingMood = containsAnyKeyword(
            in: record.emotions,
            keywords: ["sad", "lonely", "frustrated", "angry", "confused", "stuck"]
        )
        let hasUnwrittenContext = record.evidenceAgainst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return journalingMood || hasUnwrittenContext || record.intensityBefore - record.intensityAfter < 10
    }

    private static func shouldRecommendBehavioralExperiment(for record: ThoughtRecord) -> Bool {
        let experimentDistortions = ["Catastrophizing", "Fortune Telling", "Mind Reading", "Should Statements"]
        let hasExperimentDistortion = record.distortions.contains { distortion in
            experimentDistortions.contains { normalize($0) == normalize(distortion) }
        }

        let hasAvoidanceCue = containsAnyKeyword(
            in: [record.situation, record.automaticThought, record.balancedThought] + record.emotions,
            keywords: ["avoid", "avoiding", "can't", "cannot", "what if", "panic", "unsafe", "embarrass", "reassurance"]
        )

        return record.linkedExperimentIDs.isEmpty && (hasExperimentDistortion || hasAvoidanceCue)
    }

    private static func shouldRecommendRelapsePattern(for record: ThoughtRecord) -> Bool {
        if !record.relapsePatterns.isEmpty {
            return false
        }

        let smallShift = record.intensityBefore - record.intensityAfter < 10
        let stillHigh = record.intensityAfter >= 55
        let hasRecurringLanguage = containsAnyKeyword(
            in: [record.situation, record.automaticThought],
            keywords: ["again", "always", "every time", "keeps happening", "same thing", "back to"]
        )

        return stillHigh || (smallShift && hasRecurringLanguage)
    }

    private static func containsAnyKeyword(in values: [String], keywords: [String]) -> Bool {
        values.contains { value in
            let normalizedValue = normalize(value)
            return keywords.contains { normalizedValue.contains(normalize($0)) }
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension SmartCoachRecommendation {
    static let breathingReset = SmartCoachRecommendation(
        kind: .breathingReset,
        title: "Breathing reset",
        subtitle: "One minute to settle your body before moving on.",
        icon: "wind"
    )

    static func distortionLesson(_ distortion: String) -> SmartCoachRecommendation {
        SmartCoachRecommendation(
            kind: .distortionLesson(distortion: distortion),
            title: "Related distortion lesson",
            subtitle: "Look at examples of \(distortion.lowercased()).",
            icon: "brain.head.profile"
        )
    }

    static let selfCompassionExercise = SmartCoachRecommendation(
        kind: .selfCompassionExercise(exerciseID: "exercise_006"),
        title: "Self-compassion exercise",
        subtitle: "Try a brief inner-friend practice.",
        icon: "heart.text.square"
    )

    static let guidedJournal = SmartCoachRecommendation(
        kind: .guidedJournal,
        title: "Guided journal",
        subtitle: "Give the feeling a little more room on the page.",
        icon: "square.and.pencil"
    )

    static let saveHelpfulReframe = SmartCoachRecommendation(
        kind: .saveHelpfulReframe,
        title: "Save as helpful reframe",
        subtitle: "Keep your balanced thought easy to find later.",
        icon: "bookmark"
    )

    static let scheduleReReview = SmartCoachRecommendation(
        kind: .scheduleReReview,
        title: "Schedule a re-review",
        subtitle: "Check tomorrow whether this balanced thought still feels believable.",
        icon: "calendar.badge.clock"
    )

    static let beliefCheckIn = SmartCoachRecommendation(
        kind: .beliefCheckIn,
        title: "Check believability now",
        subtitle: "Notice whether your balanced thought held up after some time passed.",
        icon: "checklist.checked"
    )

    static let behavioralExperiment = SmartCoachRecommendation(
        kind: .behavioralExperiment(exerciseID: "exercise_exposure_ladder"),
        title: "Plan a tiny experiment",
        subtitle: "Turn the prediction into one small exposure or behavior test.",
        icon: "figure.step.training"
    )

    static let relapsePattern = SmartCoachRecommendation(
        kind: .relapsePattern,
        title: "Track this as a pattern",
        subtitle: "Mark the cue so future reframes can spot a returning loop.",
        icon: "arrow.triangle.2.circlepath"
    )

    static let favoriteBySituation = SmartCoachRecommendation(
        kind: .favoriteBySituation,
        title: "Favorite for this situation",
        subtitle: "Make this reframe easier to find when a similar moment shows up.",
        icon: "star"
    )

    static let reviewLater = SmartCoachRecommendation(
        kind: .reviewLater,
        title: "Review later",
        subtitle: "This record is saved. You can come back anytime.",
        icon: "clock.arrow.circlepath"
    )
}
