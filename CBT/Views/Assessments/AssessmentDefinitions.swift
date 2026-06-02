import Foundation
import SwiftUI

enum AssessmentKind: String, CaseIterable, Identifiable {
    case gad7 = "GAD-7"
    case phq8 = "PHQ-8"
    case pss4 = "PSS-4"
    case maas5 = "MAAS-5"
    case adhdAttention = "ADHD-Style Attention Screener"
    case sleepQuality = "Sleep Quality Check-In"
    case burnout = "Burnout Check-In"
    case socialAnxiety = "Social Anxiety Check-In"
    case panicSymptoms = "Panic Symptoms Check-In"
    case selfCompassion = "Self-Compassion Check-In"
    case emotionRegulation = "Emotion Regulation Check-In"
    case valuesClarity = "Values Clarity Check-In"
    case relationshipStyle = "Relationship Style Reflection"
    case wellBeing = "Well-Being Check-In"

    var id: String { rawValue }

    static var validatedTrackers: [AssessmentKind] { AssessmentDefinitionCatalog.validatedTrackers }
    static var selfReflectionCheckIns: [AssessmentKind] { AssessmentDefinitionCatalog.selfReflectionCheckIns }
}

struct AssessmentQuestion {
    let text: String
    let isReverseScored: Bool

    init(text: String, isReverseScored: Bool = false) {
        self.text = text
        self.isReverseScored = isReverseScored
    }

    func scoredValue(for answer: Int, maximumAnswer: Int) -> Int {
        isReverseScored ? maximumAnswer - answer : answer
    }
}

struct AssessmentAnswer: Identifiable {
    let id: Int
    let label: String
}

struct AssessmentNextStep: Identifiable {
    enum Destination {
        case exercise(String)
        case activityPlanner
        case affirmations
        case distortionExamples
        case guidedJournal
        case cbtGuide
        case exercises
    }

    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let destination: Destination
}

enum AssessmentScoringMode {
    case sum
    case average
}

struct AssessmentDefinition {
    let kind: AssessmentKind
    let subtitle: String
    let symbolName: String
    let prompt: String
    let questions: [AssessmentQuestion]
    let answers: [AssessmentAnswer]
    let resultTitle: String
    let fixedResultDescription: String?
    let detailedDescription: String
    let scoringMode: AssessmentScoringMode
    let isValidatedTracker: Bool
    let isSupportiveScore: Bool
    let scaleMaximum: Double
    let scoreFractionDigits: Int
    let resultFootnote: String?
    let recommendedNextSteps: [AssessmentNextStep]
    let whatItIs: String
    let symptomsCovered: [SymptomItem]
    let whyItMatters: String
    let scoringRangeText: String
    let severityLevels: [SeverityLevel]
    let scoringExplanation: String

    var title: String { kind.rawValue }
    var usesAverageScore: Bool { scoringMode == .average }

    func score(from answers: [Int?]) -> Int {
        questions.indices.reduce(0) { total, index in
            guard answers.indices.contains(index), let answer = answers[index] else { return total }
            return total + questions[index].scoredValue(for: answer, maximumAnswer: self.answers.last?.id ?? 0)
        }
    }

    func scoreValue(from answers: [Int?]) -> Double {
        guard usesAverageScore else { return Double(score(from: answers)) }
        guard answers.compactMap({ $0 }).count == questions.count else { return 0 }
        return Double(score(from: answers)) / Double(questions.count)
    }

    func scoreText(for value: Double) -> String {
        if scoreFractionDigits == 0 {
            return "\(Int(value.rounded()))"
        }

        return String(format: "%.\(scoreFractionDigits)f", value)
    }

    func interpretation(for value: Double) -> String {
        severityLevels.first { $0.contains(value) }?.label ?? "Informational Range"
    }

    func resultDescription(for value: Double) -> String {
        if let fixedResultDescription {
            return fixedResultDescription
        }

        if isSupportiveScore {
            if value < 2 {
                return "Your responses suggest this may be an area to explore. Consider discussing this with a qualified professional if it is affecting your life."
            } else if value < 3 {
                return "Your responses suggest some support here, with room to strengthen it through practice."
            } else {
                return "Your responses suggest this area may be a current support. Keep noticing what helps it stay available."
            }
        }

        if value >= 2 {
            return "Your responses suggest this may be an area to explore. Consider discussing this with a qualified professional if it is affecting your life."
        } else if value >= 1 {
            return "Your responses suggest occasional friction in this area. Tracking patterns can help you choose what to support next."
        } else {
            return "Your responses suggest this area may feel relatively steady right now. Keep tracking if it changes."
        }
    }
}

enum AssessmentDefinitionCatalog {
    static let validatedTrackers: [AssessmentKind] = [.gad7, .phq8, .pss4, .maas5]
    static let selfReflectionCheckIns: [AssessmentKind] = [
        .adhdAttention,
        .sleepQuality,
        .burnout,
        .socialAnxiety,
        .panicSymptoms,
        .selfCompassion,
        .emotionRegulation,
        .valuesClarity,
        .relationshipStyle,
        .wellBeing
    ]

    static func definition(for kind: AssessmentKind) -> AssessmentDefinition {
        guard let definition = definitionsByKind[kind] else {
            preconditionFailure("Missing assessment definition for \(kind.rawValue)")
        }

        return definition
    }

    private static let twoWeekFrequencyAnswers = [
        AssessmentAnswer(id: 0, label: "Not at all"),
        AssessmentAnswer(id: 1, label: "Several days"),
        AssessmentAnswer(id: 2, label: "More than half the days"),
        AssessmentAnswer(id: 3, label: "Nearly every day")
    ]

    private static let stressFrequencyAnswers = [
        AssessmentAnswer(id: 0, label: "Never"),
        AssessmentAnswer(id: 1, label: "Almost Never"),
        AssessmentAnswer(id: 2, label: "Sometimes"),
        AssessmentAnswer(id: 3, label: "Fairly Often"),
        AssessmentAnswer(id: 4, label: "Very Often")
    ]

    private static let mindfulnessFrequencyAnswers = [
        AssessmentAnswer(id: 1, label: "Almost Always"),
        AssessmentAnswer(id: 2, label: "Very Frequently"),
        AssessmentAnswer(id: 3, label: "Somewhat Frequently"),
        AssessmentAnswer(id: 4, label: "Somewhat Infrequently"),
        AssessmentAnswer(id: 5, label: "Very Infrequently"),
        AssessmentAnswer(id: 6, label: "Almost Never")
    ]

    private static let loadFrequencyAnswers = [
        AssessmentAnswer(id: 0, label: "Not at all"),
        AssessmentAnswer(id: 1, label: "Rarely"),
        AssessmentAnswer(id: 2, label: "Sometimes"),
        AssessmentAnswer(id: 3, label: "Often"),
        AssessmentAnswer(id: 4, label: "Very often")
    ]

    private static let supportFrequencyAnswers = [
        AssessmentAnswer(id: 0, label: "Not at all true"),
        AssessmentAnswer(id: 1, label: "A little true"),
        AssessmentAnswer(id: 2, label: "Somewhat true"),
        AssessmentAnswer(id: 3, label: "Mostly true"),
        AssessmentAnswer(id: 4, label: "Very true")
    ]

    private static let averageLoadLevels = [
        SeverityLevel(label: "Low Current Load", rangeText: "0.0 - 0.9", valueRange: 0.0...0.99, color: .green),
        SeverityLevel(label: "Occasional Friction", rangeText: "1.0 - 1.9", valueRange: 1.0...1.99, color: .yellow),
        SeverityLevel(label: "Noticeable Area to Explore", rangeText: "2.0 - 2.9", valueRange: 2.0...2.99, color: .orange),
        SeverityLevel(label: "Strong Area to Explore", rangeText: "3.0 - 4.0", valueRange: 3.0...4.0, color: .red)
    ]

    private static let averageSupportLevels = [
        SeverityLevel(label: "Needs Support", rangeText: "0.0 - 0.9", valueRange: 0.0...0.99, color: .red),
        SeverityLevel(label: "Emerging Support", rangeText: "1.0 - 1.9", valueRange: 1.0...1.99, color: .orange),
        SeverityLevel(label: "Moderate Support", rangeText: "2.0 - 2.9", valueRange: 2.0...2.99, color: .yellow),
        SeverityLevel(label: "Steady Support", rangeText: "3.0 - 4.0", valueRange: 3.0...4.0, color: .green)
    ]

    private static let allDefinitions: [AssessmentDefinition] = [
        AssessmentDefinition(
            kind: .gad7,
            subtitle: "Anxiety symptom tracking",
            symbolName: "wind",
            prompt: "Over the last 2 weeks, how often have you been bothered by the following?",
            questions: [
                AssessmentQuestion(text: "Feeling nervous, anxious or on edge"),
                AssessmentQuestion(text: "Not being able to stop or control worrying"),
                AssessmentQuestion(text: "Worrying too much about different things"),
                AssessmentQuestion(text: "Trouble relaxing"),
                AssessmentQuestion(text: "Being so restless that it is hard to sit still"),
                AssessmentQuestion(text: "Becoming easily annoyed or irritable"),
                AssessmentQuestion(text: "Feeling afraid as if something awful might happen")
            ],
            answers: twoWeekFrequencyAnswers,
            resultTitle: "Anxiety Symptom Range",
            fixedResultDescription: "This range reflects anxiety symptoms you endorsed for tracking. It is not a medical diagnosis.",
            detailedDescription: "The GAD-7 is a seven-item questionnaire commonly used to track anxiety-related symptoms such as worry, restlessness, irritability, and feeling on edge over the past two weeks.",
            scoringMode: .sum,
            isValidatedTracker: true,
            isSupportiveScore: false,
            scaleMaximum: 21,
            scoreFractionDigits: 0,
            resultFootnote: nil,
            recommendedNextSteps: [
                AssessmentNextStep(id: "box-breathing", title: "Box Breathing", subtitle: "Practice a paced breathing reset.", symbolName: "wind", destination: .exercise("exercise_004")),
                AssessmentNextStep(id: "worry-time", title: "Worry Time", subtitle: "Contain worries in a scheduled window.", symbolName: "clock", destination: .exercise("exercise_016")),
                AssessmentNextStep(id: "challenge-thought", title: "Challenge the Thought", subtitle: "Test anxious predictions against evidence.", symbolName: "brain.head.profile", destination: .exercise("exercise_009"))
            ],
            whatItIs: "The GAD-7 is a widely used symptom questionnaire. It measures and tracks the frequency of anxiety-related symptoms over the past two weeks.",
            symptomsCovered: [
                SymptomItem(description: "Feeling nervous, anxious, or on edge", symbolName: "waveform.path.ecg"),
                SymptomItem(description: "Inability to stop or control worrying", symbolName: "arrow.clockwise"),
                SymptomItem(description: "Worrying too much about different things", symbolName: "bubbles.and.sparkles"),
                SymptomItem(description: "Trouble relaxing and physical restlessness", symbolName: "wind"),
                SymptomItem(description: "Becoming easily annoyed or irritable", symbolName: "exclamationmark.bubble"),
                SymptomItem(description: "Feeling afraid as if something awful might happen", symbolName: "shield.slash")
            ],
            whyItMatters: "Tracking anxiety symptoms helps you identify worries, notice patterns or triggers over time, and evaluate whether coping practices are lowering daily arousal.",
            scoringRangeText: "Scores range from 0 to 21. These ranges describe symptom frequency for tracking, not diagnosis:",
            severityLevels: [
                SeverityLevel(label: "Minimal", rangeText: "0 - 4", valueRange: 0...4, color: .green),
                SeverityLevel(label: "Mild", rangeText: "5 - 9", valueRange: 5...9, color: .yellow),
                SeverityLevel(label: "Moderate", rangeText: "10 - 14", valueRange: 10...14, color: .orange),
                SeverityLevel(label: "Severe", rangeText: "15 - 21", valueRange: 15...21, color: .red)
            ],
            scoringExplanation: "Each item is scored from 0 to 3 based on how often the symptom was present. The items are added together, so higher totals mean symptoms were endorsed more often during the time window."
        ),
        AssessmentDefinition(
            kind: .phq8,
            subtitle: "Depression symptom tracking",
            symbolName: "heart.text.square",
            prompt: "Over the last 2 weeks, how often have you been bothered by the following?",
            questions: [
                AssessmentQuestion(text: "Little interest or pleasure in doing things"),
                AssessmentQuestion(text: "Feeling down, depressed, or hopeless"),
                AssessmentQuestion(text: "Trouble falling or staying asleep, or sleeping too much"),
                AssessmentQuestion(text: "Feeling tired or having little energy"),
                AssessmentQuestion(text: "Poor appetite or overeating"),
                AssessmentQuestion(text: "Feeling bad about yourself - or that you are a failure"),
                AssessmentQuestion(text: "Trouble concentrating on things"),
                AssessmentQuestion(text: "Moving or speaking so slowly, or being excessively fidgety/restless")
            ],
            answers: twoWeekFrequencyAnswers,
            resultTitle: "Mood Symptom Range",
            fixedResultDescription: "This range reflects mood symptoms you endorsed for tracking. It is not a medical diagnosis.",
            detailedDescription: "The PHQ-8 is an eight-item questionnaire used to monitor mood-related symptoms such as low interest, low mood, sleep, energy, appetite, self-critical thoughts, concentration, and psychomotor changes over the past two weeks.",
            scoringMode: .sum,
            isValidatedTracker: true,
            isSupportiveScore: false,
            scaleMaximum: 24,
            scoreFractionDigits: 0,
            resultFootnote: nil,
            recommendedNextSteps: [
                AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Schedule small nourishing or mastery tasks.", symbolName: "calendar.badge.clock", destination: .activityPlanner),
                AssessmentNextStep(id: "three-good-things", title: "Three Good Things", subtitle: "Notice moments your mood may filter out.", symbolName: "sparkles", destination: .exercise("exercise_005")),
                AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Reflect on patterns with a structured prompt.", symbolName: "square.and.pencil", destination: .guidedJournal)
            ],
            whatItIs: "The PHQ-8 is a standardized self-report questionnaire used to monitor depressive symptoms over the past two weeks.",
            symptomsCovered: [
                SymptomItem(description: "Little interest or pleasure in doing things", symbolName: "star.slash"),
                SymptomItem(description: "Feeling down, depressed, or hopeless", symbolName: "cloud.rain"),
                SymptomItem(description: "Trouble sleeping or sleeping too much", symbolName: "bed.double"),
                SymptomItem(description: "Feeling tired or having little energy", symbolName: "bolt.slash"),
                SymptomItem(description: "Poor appetite or overeating", symbolName: "fork.knife"),
                SymptomItem(description: "Feeling bad about yourself or like a failure", symbolName: "person.text.rectangle"),
                SymptomItem(description: "Trouble concentrating on daily activities", symbolName: "target"),
                SymptomItem(description: "Moving or speaking slowly, or being fidgety", symbolName: "slowmo")
            ],
            whyItMatters: "Regular PHQ-8 tracking provides a longer-term snapshot of mood patterns, helping you recognize changes beyond minor daily ups and downs.",
            scoringRangeText: "Scores range from 0 to 24. These ranges describe symptom frequency for tracking, not diagnosis:",
            severityLevels: [
                SeverityLevel(label: "Minimal", rangeText: "0 - 4", valueRange: 0...4, color: .green),
                SeverityLevel(label: "Mild", rangeText: "5 - 9", valueRange: 5...9, color: .yellow),
                SeverityLevel(label: "Moderate", rangeText: "10 - 14", valueRange: 10...14, color: .orange),
                SeverityLevel(label: "Severe", rangeText: "15 - 24", valueRange: 15...24, color: .red)
            ],
            scoringExplanation: "Each item is scored from 0 to 3 based on how often the symptom was present. The items are added together, so higher totals mean symptoms were endorsed more often during the time window."
        ),
        AssessmentDefinition(
            kind: .pss4,
            subtitle: "Lifestyle stress tracking",
            symbolName: "gauge.with.dots.needle.67percent",
            prompt: "In the past month...",
            questions: [
                AssessmentQuestion(text: "How often have you felt that you were unable to control the important things in your life?"),
                AssessmentQuestion(text: "How often have you felt confident about your ability to handle your personal problems?", isReverseScored: true),
                AssessmentQuestion(text: "How often have you felt that things were going your way?", isReverseScored: true),
                AssessmentQuestion(text: "How often have you felt difficulties were piling up so high that you could not overcome them?")
            ],
            answers: stressFrequencyAnswers,
            resultTitle: "Perceived Stress Range",
            fixedResultDescription: "This range reflects perceived stress for self-tracking. It is not a medical diagnosis.",
            detailedDescription: "The PSS-4 is a brief self-report measure for how unpredictable, uncontrollable, and overloaded life has felt recently.",
            scoringMode: .sum,
            isValidatedTracker: true,
            isSupportiveScore: false,
            scaleMaximum: 16,
            scoreFractionDigits: 0,
            resultFootnote: nil,
            recommendedNextSteps: [
                AssessmentNextStep(id: "identify-stressor", title: "Identify the Stressor", subtitle: "Separate the stressor from the story around it.", symbolName: "scope", destination: .exercise("exercise_001")),
                AssessmentNextStep(id: "shoulder-drop", title: "Shoulder Drop", subtitle: "Release tension with a quick body reset.", symbolName: "figure.mind.and.body", destination: .exercise("exercise_020")),
                AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Make the next few responsibilities visible and smaller.", symbolName: "calendar.badge.clock", destination: .activityPlanner)
            ],
            whatItIs: "The PSS-4 is a brief self-report measure designed to evaluate how unpredictable, uncontrollable, and overloaded you perceive current life circumstances to be.",
            symptomsCovered: [
                SymptomItem(description: "Feeling unable to control important life events", symbolName: "exclamationmark.shield"),
                SymptomItem(description: "Confidence in handling personal difficulties", symbolName: "hand.thumbsup"),
                SymptomItem(description: "Feeling that things are going your way", symbolName: "sun.max"),
                SymptomItem(description: "Feeling difficulties piling up too high to overcome", symbolName: "barometer")
            ],
            whyItMatters: "Measuring subjective stress load can help you identify when demands are exceeding perceived coping capacity and when support or recovery needs priority.",
            scoringRangeText: "Scores range from 0 to 16. Higher scores reflect more perceived stress in this self-report snapshot:",
            severityLevels: [
                SeverityLevel(label: "Low Stress", rangeText: "0 - 5", valueRange: 0...5, color: .green),
                SeverityLevel(label: "Moderate Stress", rangeText: "6 - 10", valueRange: 6...10, color: .orange),
                SeverityLevel(label: "High Stress", rangeText: "11 - 16", valueRange: 11...16, color: .red)
            ],
            scoringExplanation: "Each item is scored from 0 to 4. The confidence and things-going-your-way items are reverse-scored because they describe coping resources rather than stress load. The four scored items are then added together."
        ),
        AssessmentDefinition(
            kind: .maas5,
            subtitle: "Mindful attention tracking",
            symbolName: "leaf",
            prompt: "How frequently do you experience each of the following?",
            questions: [
                AssessmentQuestion(text: "I could be experiencing some emotion and not be conscious of it until some time later."),
                AssessmentQuestion(text: "I break or spill things because of carelessness, not paying attention, or thinking of something else."),
                AssessmentQuestion(text: "I find it difficult to stay focused on what's happening in the present."),
                AssessmentQuestion(text: "I do jobs or tasks automatically, without being aware of what I'm doing."),
                AssessmentQuestion(text: "I rush through activities without being really attentive to them.")
            ],
            answers: mindfulnessFrequencyAnswers,
            resultTitle: "Mindful Awareness Range",
            fixedResultDescription: "This range reflects day-to-day mindful attention for self-tracking. It is not a psychological or clinical evaluation.",
            detailedDescription: "The MAAS-5 is a compact self-report snapshot of mindful attention and present-moment awareness in everyday activities.",
            scoringMode: .average,
            isValidatedTracker: true,
            isSupportiveScore: true,
            scaleMaximum: 6,
            scoreFractionDigits: 1,
            resultFootnote: nil,
            recommendedNextSteps: [
                AssessmentNextStep(id: "five-senses", title: "5-4-3-2-1 Technique", subtitle: "Anchor attention through the senses.", symbolName: "hand.raised", destination: .exercise("exercise_003")),
                AssessmentNextStep(id: "color-focus", title: "Color Focus", subtitle: "Use a simple attention target in your environment.", symbolName: "eye", destination: .exercise("exercise_011")),
                AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Notice moments of autopilot and presence.", symbolName: "square.and.pencil", destination: .guidedJournal)
            ],
            whatItIs: "The MAAS-5 measures a core component of mindfulness: receptive awareness of and attention to what is taking place in the present moment.",
            symptomsCovered: [
                SymptomItem(description: "Awareness of emotions as they arise", symbolName: "heart.text.square"),
                SymptomItem(description: "Paying attention to actions to avoid carelessness", symbolName: "hand.raised"),
                SymptomItem(description: "Staying focused on what is happening now", symbolName: "eye"),
                SymptomItem(description: "Performing tasks consciously rather than on autopilot", symbolName: "brain"),
                SymptomItem(description: "Engaging fully in activities without rushing", symbolName: "hourglass.badge.arrow.recenter")
            ],
            whyItMatters: "Mindfulness can buffer stress. MAAS-5 tracking shows how often you are living on autopilot and can prompt small present-moment anchors.",
            scoringRangeText: "Scores represent the average response on a 1-6 scale. Higher averages reflect more mindful awareness in this self-report snapshot:",
            severityLevels: [
                SeverityLevel(label: "Low Mindfulness/High Distraction", rangeText: "1.0 - 2.9", valueRange: 1.0...2.99, color: .red),
                SeverityLevel(label: "Moderate Mindfulness", rangeText: "3.0 - 4.5", valueRange: 3.0...4.5, color: .orange),
                SeverityLevel(label: "High Mindful Awareness", rangeText: "4.6 - 6.0", valueRange: 4.51...6.0, color: .green)
            ],
            scoringExplanation: "Each item is scored from 1 to 6 and the final score is the average. Higher averages mean more mindful attention and less autopilot responding."
        )
    ] + reflectionDefinitions

    private static let reflectionDefinitions: [AssessmentDefinition] = [
        loadCheckIn(kind: .adhdAttention, subtitle: "Attention and follow-through reflection", symbolName: "scope", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Attention Load", questions: [
            AssessmentQuestion(text: "I lost track of tasks, appointments, or items even when I meant to stay organized."),
            AssessmentQuestion(text: "I had trouble starting tasks that required sustained mental effort."),
            AssessmentQuestion(text: "I jumped between tasks before finishing what I started."),
            AssessmentQuestion(text: "I felt restless, fidgety, or driven to keep moving."),
            AssessmentQuestion(text: "I underestimated how long tasks would take."),
            AssessmentQuestion(text: "I interrupted, blurted things out, or acted before fully thinking it through.")
        ], detailedDescription: "This informational reflection looks at attention, organization, restlessness, time awareness, and follow-through. It is not an ADHD diagnosis or a validated ADHD assessment.", trackedItems: [
            SymptomItem(description: "Organization and remembering intended tasks", symbolName: "checklist"),
            SymptomItem(description: "Starting effortful tasks", symbolName: "play.circle"),
            SymptomItem(description: "Following through before switching tasks", symbolName: "arrow.triangle.branch"),
            SymptomItem(description: "Restlessness and fidgeting", symbolName: "figure.walk.motion"),
            SymptomItem(description: "Time awareness and impulsive responding", symbolName: "clock")
        ], whyItMatters: "Attention patterns can change with stress, sleep, workload, environment, and support. Tracking them can help you notice when external structure, smaller next steps, or professional guidance may be useful.", recommendedNextSteps: [
            AssessmentNextStep(id: "routine-anchor", title: "Routine Anchor", subtitle: "Attach a small task to an existing cue.", symbolName: "link", destination: .exercise("exercise_023")),
            AssessmentNextStep(id: "do-one-small-thing", title: "Do One Small Thing", subtitle: "Create momentum with one low-friction action.", symbolName: "checkmark.circle", destination: .exercise("exercise_007")),
            AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Externalize the next steps and schedule them.", symbolName: "calendar.badge.clock", destination: .activityPlanner)
        ]),
        loadCheckIn(kind: .sleepQuality, subtitle: "Rest, routine, and daytime energy", symbolName: "bed.double", prompt: "Over the last 7 nights, how often was this true?", resultTitle: "Sleep Strain", questions: [
            AssessmentQuestion(text: "I had trouble falling asleep."),
            AssessmentQuestion(text: "I woke during the night or earlier than I wanted."),
            AssessmentQuestion(text: "I woke up feeling unrefreshed."),
            AssessmentQuestion(text: "Racing thoughts, screens, or stimulation made winding down harder."),
            AssessmentQuestion(text: "My daytime energy or focus was affected by sleep."),
            AssessmentQuestion(text: "My sleep schedule shifted more than I wanted it to.")
        ], detailedDescription: "This informational check-in looks at sleep continuity, wind-down, schedule consistency, and daytime impact. It is not a sleep disorder assessment.", trackedItems: [
            SymptomItem(description: "Falling asleep and staying asleep", symbolName: "moon"),
            SymptomItem(description: "Waking rested", symbolName: "sunrise"),
            SymptomItem(description: "Wind-down barriers like racing thoughts or screens", symbolName: "iphone.slash"),
            SymptomItem(description: "Daytime energy and focus", symbolName: "bolt"),
            SymptomItem(description: "Sleep schedule consistency", symbolName: "calendar")
        ], whyItMatters: "Sleep affects mood, attention, emotion regulation, and resilience. A short check-in can help you connect rest patterns with daytime coping.", recommendedNextSteps: [
            AssessmentNextStep(id: "progressive-relaxation", title: "Progressive Relaxation", subtitle: "Wind down by releasing muscle tension.", symbolName: "bed.double", destination: .exercise("exercise_012")),
            AssessmentNextStep(id: "four-seven-eight", title: "4-7-8 Breathing", subtitle: "Use a calming breath pattern before rest.", symbolName: "wind", destination: .exercise("exercise_028")),
            AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Track evening cues that help or hinder sleep.", symbolName: "square.and.pencil", destination: .guidedJournal)
        ]),
        loadCheckIn(kind: .burnout, subtitle: "Exhaustion and recovery reflection", symbolName: "flame", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Burnout Strain", questions: [
            AssessmentQuestion(text: "I felt emotionally drained by my responsibilities."),
            AssessmentQuestion(text: "It was harder to care about work, study, caregiving, or home tasks."),
            AssessmentQuestion(text: "I dreaded tasks before I started them."),
            AssessmentQuestion(text: "Small demands felt like too much."),
            AssessmentQuestion(text: "Rest or downtime did not feel restorative."),
            AssessmentQuestion(text: "I felt less effective or accomplished despite trying.")
        ], detailedDescription: "This informational check-in looks at exhaustion, detachment, dread, recovery, and perceived effectiveness. It is not a clinical diagnosis.", trackedItems: [
            SymptomItem(description: "Emotional exhaustion", symbolName: "battery.25"),
            SymptomItem(description: "Detachment or reduced care", symbolName: "heart.slash"),
            SymptomItem(description: "Dread before demands", symbolName: "exclamationmark.triangle"),
            SymptomItem(description: "Recovery that does not feel restorative", symbolName: "bed.double"),
            SymptomItem(description: "Feeling less effective despite effort", symbolName: "chart.line.downtrend.xyaxis")
        ], whyItMatters: "Burnout patterns often build gradually. Tracking exhaustion and recovery can help you notice when your load needs adjustment before depletion becomes the default.", recommendedNextSteps: [
            AssessmentNextStep(id: "pleasant-scheduling", title: "Pleasant Activity Scheduling", subtitle: "Add restoration instead of only obligations.", symbolName: "calendar.badge.plus", destination: .exercise("exercise_015")),
            AssessmentNextStep(id: "inner-friend", title: "Inner Friend", subtitle: "Respond to depletion with a kinder voice.", symbolName: "heart.circle", destination: .exercise("exercise_006")),
            AssessmentNextStep(id: "shoulder-drop", title: "Shoulder Drop", subtitle: "Give your body a brief reset between demands.", symbolName: "figure.mind.and.body", destination: .exercise("exercise_020"))
        ]),
        loadCheckIn(kind: .socialAnxiety, subtitle: "Social ease and avoidance patterns", symbolName: "person.2.wave.2", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Social Ease Load", questions: [
            AssessmentQuestion(text: "I worried about being judged, embarrassed, or rejected."),
            AssessmentQuestion(text: "I avoided speaking up or joining social situations."),
            AssessmentQuestion(text: "I replayed conversations afterward looking for mistakes."),
            AssessmentQuestion(text: "My body felt tense, flushed, shaky, or on alert around people."),
            AssessmentQuestion(text: "I held back needs or opinions to avoid disapproval."),
            AssessmentQuestion(text: "Social interactions felt draining because I was monitoring myself.")
        ], detailedDescription: "This informational check-in looks at social worry, avoidance, self-monitoring, and post-interaction rumination. It is not a social anxiety disorder assessment.", trackedItems: [
            SymptomItem(description: "Worry about judgment or rejection", symbolName: "person.crop.circle.badge.exclamationmark"),
            SymptomItem(description: "Avoiding speaking up or joining in", symbolName: "bubble.left.and.bubble.right"),
            SymptomItem(description: "Replaying conversations afterward", symbolName: "arrow.counterclockwise"),
            SymptomItem(description: "Body tension around people", symbolName: "waveform.path.ecg"),
            SymptomItem(description: "Self-monitoring and holding back", symbolName: "eye")
        ], whyItMatters: "Social worry can quietly shape avoidance and self-expression. Tracking it can help you choose small experiments that build confidence without forcing yourself too far too fast.", recommendedNextSteps: [
            AssessmentNextStep(id: "mind-reading-check", title: "Mind Reading Check", subtitle: "Question assumptions about what others think.", symbolName: "person.crop.circle.badge.questionmark", destination: .exercise("exercise_010")),
            AssessmentNextStep(id: "safety-behavior-drop", title: "Safety Behavior Drop", subtitle: "Experiment with reducing one protective habit.", symbolName: "shield.lefthalf.filled", destination: .exercise("exercise_032")),
            AssessmentNextStep(id: "five-senses", title: "5-4-3-2-1 Technique", subtitle: "Ground before or after social stress.", symbolName: "hand.raised", destination: .exercise("exercise_003"))
        ]),
        loadCheckIn(kind: .panicSymptoms, subtitle: "Body alarm and avoidance patterns", symbolName: "waveform.path.ecg", prompt: "Over the last month, how often did you notice this?", resultTitle: "Body Alarm Load", questions: [
            AssessmentQuestion(text: "I had sudden waves of intense fear or discomfort."),
            AssessmentQuestion(text: "I noticed racing heart, tight chest, shortness of breath, dizziness, or similar body alarms."),
            AssessmentQuestion(text: "When sensations rose, I worried I might lose control, faint, or be unsafe."),
            AssessmentQuestion(text: "I avoided places or activities because intense body sensations might show up."),
            AssessmentQuestion(text: "I checked body sensations or scanned for signs that something was wrong."),
            AssessmentQuestion(text: "I needed extra reassurance, escape plans, or safety behaviors to feel okay.")
        ], detailedDescription: "This informational check-in looks at sudden body-alarm sensations, fear responses, avoidance, and safety behaviors. It is not a panic disorder assessment.", trackedItems: [
            SymptomItem(description: "Sudden waves of fear or discomfort", symbolName: "waveform.path.ecg"),
            SymptomItem(description: "Body alarm sensations", symbolName: "heart"),
            SymptomItem(description: "Fearful interpretations of sensations", symbolName: "exclamationmark.bubble"),
            SymptomItem(description: "Avoidance related to sensations", symbolName: "figure.walk.departure"),
            SymptomItem(description: "Body scanning and safety behaviors", symbolName: "shield")
        ], whyItMatters: "Body alarm sensations can feel frightening even when they pass. Tracking patterns can help you pair grounding tools with situations where avoidance has been growing.", recommendedNextSteps: [
            AssessmentNextStep(id: "box-breathing", title: "Box Breathing", subtitle: "Practice steadier breathing during body alarm.", symbolName: "wind", destination: .exercise("exercise_004")),
            AssessmentNextStep(id: "five-senses", title: "5-4-3-2-1 Technique", subtitle: "Orient to the present when sensations spike.", symbolName: "hand.raised", destination: .exercise("exercise_003")),
            AssessmentNextStep(id: "decatastrophize", title: "Decatastrophize a Fear", subtitle: "Name the feared outcome and a more balanced possibility.", symbolName: "arrow.down.right.and.arrow.up.left", destination: .exercise("exercise_024"))
        ], resultFootnote: "If body symptoms feel new, severe, or medically urgent, seek medical care promptly."),
        supportCheckIn(kind: .selfCompassion, subtitle: "Kindness toward yourself under stress", symbolName: "heart.circle", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Self-Compassion Support", questions: [
            AssessmentQuestion(text: "I spoke to myself kindly after a mistake or hard moment."),
            AssessmentQuestion(text: "I remembered that struggle is part of being human."),
            AssessmentQuestion(text: "I gave myself permission to rest, ask for support, or go slowly."),
            AssessmentQuestion(text: "I noticed harsh self-talk and softened it."),
            AssessmentQuestion(text: "I treated my needs as valid."),
            AssessmentQuestion(text: "I acknowledged my effort even when the outcome was imperfect.")
        ], detailedDescription: "This informational check-in looks at kind self-talk, common humanity, rest, and validation of your needs. It is for self-reflection, not clinical evaluation.", trackedItems: [
            SymptomItem(description: "Kind self-talk after mistakes", symbolName: "quote.bubble"),
            SymptomItem(description: "Remembering shared humanity", symbolName: "person.2"),
            SymptomItem(description: "Permission to rest or ask for support", symbolName: "bed.double"),
            SymptomItem(description: "Softening harsh self-criticism", symbolName: "heart.circle"),
            SymptomItem(description: "Acknowledging effort", symbolName: "checkmark.seal")
        ], whyItMatters: "Self-compassion can make hard moments easier to recover from. Tracking it helps you notice whether your inner voice is supporting change or making it heavier.", recommendedNextSteps: [
            AssessmentNextStep(id: "inner-friend", title: "Inner Friend", subtitle: "Practice a supportive response to yourself.", symbolName: "heart.circle", destination: .exercise("exercise_006")),
            AssessmentNextStep(id: "shared-humanity", title: "Shared Humanity", subtitle: "Reduce isolation around struggle.", symbolName: "person.2", destination: .exercise("exercise_030")),
            AssessmentNextStep(id: "soothing-touch", title: "Soothing Touch", subtitle: "Use a brief physical cue for kindness.", symbolName: "hand.raised", destination: .exercise("exercise_022"))
        ]),
        supportCheckIn(kind: .emotionRegulation, subtitle: "Naming, pausing, and choosing responses", symbolName: "dial.low", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Emotion Regulation Support", questions: [
            AssessmentQuestion(text: "I could name what I was feeling before reacting."),
            AssessmentQuestion(text: "I paused, breathed, or grounded myself when emotions got intense."),
            AssessmentQuestion(text: "I chose actions that fit my longer-term goals."),
            AssessmentQuestion(text: "I recovered after getting upset without judging myself for having feelings."),
            AssessmentQuestion(text: "I asked for support, space, or clarification when I needed it."),
            AssessmentQuestion(text: "I noticed early body cues before emotions took over.")
        ], detailedDescription: "This informational check-in looks at naming emotions, pausing, grounding, choosing actions, and recovering after upset. It is for self-reflection, not clinical evaluation.", trackedItems: [
            SymptomItem(description: "Naming emotions before reacting", symbolName: "tag"),
            SymptomItem(description: "Pausing, breathing, or grounding", symbolName: "wind"),
            SymptomItem(description: "Choosing actions that fit longer-term goals", symbolName: "target"),
            SymptomItem(description: "Recovering after upset", symbolName: "arrow.up.heart"),
            SymptomItem(description: "Noticing early body cues", symbolName: "figure.mind.and.body")
        ], whyItMatters: "Emotion regulation is not about suppressing feelings. Tracking it helps you see whether you can notice emotions, pause, and choose responses that fit your needs and values.", recommendedNextSteps: [
            AssessmentNextStep(id: "identify-stressor", title: "Identify the Stressor", subtitle: "Name the trigger before choosing a response.", symbolName: "scope", destination: .exercise("exercise_001")),
            AssessmentNextStep(id: "shoulder-drop", title: "Shoulder Drop", subtitle: "Create a pause when emotion intensity rises.", symbolName: "figure.mind.and.body", destination: .exercise("exercise_020")),
            AssessmentNextStep(id: "cbt-guide", title: "What Is CBT?", subtitle: "Review the thought-feeling-behavior loop.", symbolName: "map", destination: .cbtGuide)
        ]),
        supportCheckIn(kind: .valuesClarity, subtitle: "Direction, priorities, and meaning", symbolName: "safari", prompt: "Over the last month, how often was this true?", resultTitle: "Values Clarity", questions: [
            AssessmentQuestion(text: "I knew what mattered most when making choices."),
            AssessmentQuestion(text: "My actions matched the kind of person I want to be."),
            AssessmentQuestion(text: "I could name a value underneath a goal, boundary, or decision."),
            AssessmentQuestion(text: "I made room for activities that felt meaningful."),
            AssessmentQuestion(text: "I noticed when I was acting from pressure, avoidance, or people-pleasing."),
            AssessmentQuestion(text: "I felt connected to a direction that matters to me.")
        ], detailedDescription: "This informational check-in looks at direction, meaning, priorities, and actions that fit your values. It is for self-reflection, not clinical evaluation.", trackedItems: [
            SymptomItem(description: "Knowing what matters in decisions", symbolName: "safari"),
            SymptomItem(description: "Acting in line with chosen values", symbolName: "checkmark.seal"),
            SymptomItem(description: "Making room for meaningful activities", symbolName: "calendar.badge.plus"),
            SymptomItem(description: "Spotting pressure, avoidance, or people-pleasing", symbolName: "eye"),
            SymptomItem(description: "Feeling connected to direction", symbolName: "arrow.up.right")
        ], whyItMatters: "Clear values make next steps easier to choose. Tracking clarity can reveal when your choices are guided by what matters versus pressure, avoidance, or autopilot.", recommendedNextSteps: [
            AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Turn a value into one scheduled action.", symbolName: "calendar.badge.clock", destination: .activityPlanner),
            AssessmentNextStep(id: "pleasant-scheduling", title: "Pleasant Activity Scheduling", subtitle: "Make room for nourishing activities.", symbolName: "calendar.badge.plus", destination: .exercise("exercise_015")),
            AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Clarify what matters before the next step.", symbolName: "square.and.pencil", destination: .guidedJournal)
        ]),
        supportCheckIn(kind: .relationshipStyle, subtitle: "Closeness, boundaries, and repair", symbolName: "person.2", prompt: "Over the last month, how often was this true?", resultTitle: "Relationship Flexibility", questions: [
            AssessmentQuestion(text: "I asked for reassurance, support, or clarity directly."),
            AssessmentQuestion(text: "I respected my boundaries and other people's boundaries."),
            AssessmentQuestion(text: "During conflict, I could stay present without attacking or shutting down."),
            AssessmentQuestion(text: "I noticed fears of rejection or distance without letting them take over."),
            AssessmentQuestion(text: "I repaired, apologized, or clarified misunderstandings when needed."),
            AssessmentQuestion(text: "I felt able to balance closeness with independence.")
        ], detailedDescription: "This informational reflection looks at reassurance, boundaries, conflict, repair, and balancing closeness with independence. It is not a clinical attachment assessment.", trackedItems: [
            SymptomItem(description: "Asking directly for support or clarity", symbolName: "bubble.left.and.bubble.right"),
            SymptomItem(description: "Respecting boundaries", symbolName: "hand.raised"),
            SymptomItem(description: "Staying present during conflict", symbolName: "person.2"),
            SymptomItem(description: "Noticing fears without letting them lead", symbolName: "eye"),
            SymptomItem(description: "Repairing misunderstandings", symbolName: "wrench.and.screwdriver")
        ], whyItMatters: "Relationship patterns are easier to shift when you can see them clearly. Tracking helps you notice how you ask for support, handle closeness, set boundaries, and repair conflict.", recommendedNextSteps: [
            AssessmentNextStep(id: "appreciation-letter", title: "Appreciation Letter", subtitle: "Practice explicit warmth and connection.", symbolName: "envelope", destination: .exercise("exercise_013")),
            AssessmentNextStep(id: "mind-reading-check", title: "Mind Reading Check", subtitle: "Check assumptions before reacting.", symbolName: "person.crop.circle.badge.questionmark", destination: .exercise("exercise_010")),
            AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Reflect on needs, boundaries, and repair.", symbolName: "square.and.pencil", destination: .guidedJournal)
        ]),
        supportCheckIn(kind: .wellBeing, subtitle: "Everyday energy, meaning, and steadiness", symbolName: "sun.max", prompt: "Over the last 2 weeks, how often was this true?", resultTitle: "Well-Being Support", questions: [
            AssessmentQuestion(text: "I had moments of calm, enjoyment, or interest."),
            AssessmentQuestion(text: "I had enough energy for important routines."),
            AssessmentQuestion(text: "I felt connected to someone or something meaningful."),
            AssessmentQuestion(text: "I cared for physical needs like food, movement, hydration, or rest."),
            AssessmentQuestion(text: "I noticed things that were going okay."),
            AssessmentQuestion(text: "I felt able to handle ordinary stressors.")
        ], detailedDescription: "This informational check-in looks at calm, energy, connection, physical care, appreciation, and everyday steadiness. It is for self-reflection, not clinical evaluation.", trackedItems: [
            SymptomItem(description: "Moments of calm, enjoyment, or interest", symbolName: "sun.max"),
            SymptomItem(description: "Energy for important routines", symbolName: "bolt"),
            SymptomItem(description: "Connection and meaning", symbolName: "sparkles"),
            SymptomItem(description: "Physical care basics", symbolName: "figure.walk"),
            SymptomItem(description: "Capacity for ordinary stressors", symbolName: "gauge.with.dots.needle.67percent")
        ], whyItMatters: "Well-being is more than symptom reduction. Tracking everyday energy, meaning, connection, and care can help you protect the small things that keep you steady.", recommendedNextSteps: [
            AssessmentNextStep(id: "three-good-things", title: "Three Good Things", subtitle: "Build a record of what is still working.", symbolName: "sparkles", destination: .exercise("exercise_005")),
            AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Plan one small action for energy or meaning.", symbolName: "calendar.badge.clock", destination: .activityPlanner),
            AssessmentNextStep(id: "affirmations", title: "Affirmations", subtitle: "Use a brief supportive mindset reset.", symbolName: "quote.bubble", destination: .affirmations)
        ])
    ]

    private static let definitionsByKind = Dictionary(uniqueKeysWithValues: allDefinitions.map { ($0.kind, $0) })

    private static func loadCheckIn(
        kind: AssessmentKind,
        subtitle: String,
        symbolName: String,
        prompt: String,
        resultTitle: String,
        questions: [AssessmentQuestion],
        detailedDescription: String,
        trackedItems: [SymptomItem],
        whyItMatters: String,
        recommendedNextSteps: [AssessmentNextStep],
        resultFootnote: String? = nil
    ) -> AssessmentDefinition {
        AssessmentDefinition(
            kind: kind,
            subtitle: subtitle,
            symbolName: symbolName,
            prompt: prompt,
            questions: questions,
            answers: loadFrequencyAnswers,
            resultTitle: resultTitle,
            fixedResultDescription: nil,
            detailedDescription: detailedDescription,
            scoringMode: .average,
            isValidatedTracker: false,
            isSupportiveScore: false,
            scaleMaximum: 4,
            scoreFractionDigits: 1,
            resultFootnote: resultFootnote,
            recommendedNextSteps: recommendedNextSteps,
            whatItIs: detailedDescription,
            symptomsCovered: trackedItems,
            whyItMatters: whyItMatters,
            scoringRangeText: "Scores represent your average response from 0 to 4. Higher scores reflect more frequent patterns in this self-reflection check-in:",
            severityLevels: averageLoadLevels,
            scoringExplanation: "Each item is scored from 0 to 4 and the final score is the average. Higher averages mean this area showed up more often in your responses."
        )
    }

    private static func supportCheckIn(
        kind: AssessmentKind,
        subtitle: String,
        symbolName: String,
        prompt: String,
        resultTitle: String,
        questions: [AssessmentQuestion],
        detailedDescription: String,
        trackedItems: [SymptomItem],
        whyItMatters: String,
        recommendedNextSteps: [AssessmentNextStep]
    ) -> AssessmentDefinition {
        AssessmentDefinition(
            kind: kind,
            subtitle: subtitle,
            symbolName: symbolName,
            prompt: prompt,
            questions: questions,
            answers: supportFrequencyAnswers,
            resultTitle: resultTitle,
            fixedResultDescription: nil,
            detailedDescription: detailedDescription,
            scoringMode: .average,
            isValidatedTracker: false,
            isSupportiveScore: true,
            scaleMaximum: 4,
            scoreFractionDigits: 1,
            resultFootnote: nil,
            recommendedNextSteps: recommendedNextSteps,
            whatItIs: detailedDescription,
            symptomsCovered: trackedItems,
            whyItMatters: whyItMatters,
            scoringRangeText: "Scores represent your average response from 0 to 4. Higher scores reflect more available support in this self-reflection check-in:",
            severityLevels: averageSupportLevels,
            scoringExplanation: "Each item is scored from 0 to 4 and the final score is the average. Higher averages mean this supportive skill or resource was more available in your responses."
        )
    }
}


struct SymptomItem: Identifiable {
    var id: String { description }
    let description: String
    let symbolName: String
}

struct SeverityLevel: Identifiable {
    let id = UUID()
    let label: String
    let rangeText: String
    let valueRange: ClosedRange<Double>?
    let color: Color

    init(
        label: String,
        rangeText: String,
        valueRange: ClosedRange<Double>? = nil,
        color: Color
    ) {
        self.label = label
        self.rangeText = rangeText
        self.valueRange = valueRange
        self.color = color
    }

    func contains(_ value: Double) -> Bool {
        guard let valueRange else { return false }
        return value >= valueRange.lowerBound && value <= valueRange.upperBound
    }
}

extension AssessmentKind {
    var definition: AssessmentDefinition {
        AssessmentDefinitionCatalog.definition(for: self)
    }

    var title: String { self.definition.title }
    var subtitle: String { self.definition.subtitle }
    var symbolName: String { self.definition.symbolName }
    var prompt: String { self.definition.prompt }
    var questions: [AssessmentQuestion] { self.definition.questions }
    var answers: [AssessmentAnswer] { self.definition.answers }
    var resultTitle: String { self.definition.resultTitle }
    var recommendedNextSteps: [AssessmentNextStep] { self.definition.recommendedNextSteps }
    var scaleMaximum: Double { self.definition.scaleMaximum }
    var isSupportiveScore: Bool { self.definition.isSupportiveScore }
    var whatItIs: String { self.definition.whatItIs }
    var whyItMatters: String { self.definition.whyItMatters }
    var scoringRangeText: String { self.definition.scoringRangeText }
    var scoringExplanation: String { self.definition.scoringExplanation }
    var symptomsCovered: [SymptomItem] { self.definition.symptomsCovered }
    var severityLevels: [SeverityLevel] { self.definition.severityLevels }
    var resultFootnote: String? { self.definition.resultFootnote }
    var usesAverageScore: Bool { self.definition.usesAverageScore }

    var scoreRangeLabel: String {
        if usesAverageScore {
            return self == .maas5 ? "1.0 to 6.0 average" : "0.0 to 4.0 average"
        }

        return "0 to \(Int(scaleMaximum))"
    }

    func score(from answers: [Int?]) -> Int {
        self.definition.score(from: answers)
    }

    func scoreValue(from answers: [Int?]) -> Double {
        self.definition.scoreValue(from: answers)
    }

    func scoreText(for value: Double) -> String {
        self.definition.scoreText(for: value)
    }

    func interpretation(for value: Double) -> String {
        self.definition.interpretation(for: value)
    }

    func resultDescription(for value: Double) -> String {
        self.definition.resultDescription(for: value)
    }

    func resultExplanation(for value: Double) -> String {
        let score = scoreText(for: value)
        let label = interpretation(for: value)

        switch self {
        case .gad7:
            return "Your GAD-7 score is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. Higher scores mean anxiety-related symptoms were reported more often over the last two weeks. This is best used as a tracking signal, not a diagnosis."
        case .phq8:
            return "Your PHQ-8 score is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. Higher scores mean mood-related symptoms were reported more often over the last two weeks. This can help you spot patterns over time and decide when extra support may be useful."
        case .pss4:
            return "Your PSS-4 score is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. The score reflects perceived stress: how unpredictable, uncontrollable, or overloaded life has felt lately."
        case .maas5:
            return "Your MAAS-5 average is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. Higher scores suggest more present-moment awareness; lower scores suggest more autopilot, distraction, or mind-wandering."
        case .adhdAttention, .sleepQuality, .burnout, .socialAnxiety, .panicSymptoms:
            return "Your average is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. This is an informational check-in: higher averages point to a pattern worth exploring, especially if it affects daily life, relationships, work, school, or safety."
        case .selfCompassion, .emotionRegulation, .valuesClarity, .relationshipStyle, .wellBeing:
            return "Your average is \(score) on a \(scoreRangeLabel) scale, which falls in the \(label) range. This is an informational reflection: higher averages suggest this resource was more available, while lower averages can point to a skill or support to practice gently."
        }
    }

    func answerText(for answer: Int?) -> String {
        guard let answer else { return "No answer" }
        guard let match = answers.first(where: { $0.id == answer }) else {
            return "\(answer)"
        }
        return "\(match.label) (\(answer))"
    }

    func answerScoreText(question: AssessmentQuestion, answer: Int?) -> String {
        guard let answer else { return "No score" }
        let scored = question.scoredValue(for: answer, maximumAnswer: answers.last?.id ?? 0)

        if question.isReverseScored {
            return "Counts as \(scored)"
        }

        return usesAverageScore ? "Value \(scored)" : "Score +\(scored)"
    }

    func exportText(answers: [Int?], completedAt: Date) -> String {
        let value = scoreValue(from: answers)
        let scoreLine = usesAverageScore
            ? "\(scoreText(for: value)) average (\(scoreRangeLabel))"
            : "\(scoreText(for: value)) (\(scoreRangeLabel))"
        let nextSteps = recommendedNextSteps
            .map { "- \($0.title): \($0.subtitle)" }
            .joined(separator: "\n")
        let answerLines = questions.indices
            .map { index in
                let question = questions[index]
                let answer = answers.indices.contains(index) ? answers[index] : nil
                return "\(index + 1). \(question.text)\n   Answer: \(answerText(for: answer)) | \(answerScoreText(question: question, answer: answer))"
            }
            .joined(separator: "\n")
        let footnote = resultFootnote.map { "\n\nImportant note:\n\($0)" } ?? ""

        return """
        \(title) Result
        Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))

        Score: \(scoreLine)
        Interpretation: \(interpretation(for: value))

        Summary:
        \(resultDescription(for: value))

        What this means:
        \(resultExplanation(for: value))

        How it is scored:
        \(scoringExplanation)

        Recommended next steps:
        \(nextSteps)

        Answers:
        \(answerLines)

        Note:
        This assessment is for informational and tracking purposes only. It is not a medical diagnosis or a substitute for professional clinical advice.\(footnote)
        """
    }
}

enum PersonalityTrait: String, CaseIterable, Identifiable {
    case openness = "Openness"
    case conscientiousness = "Conscientiousness"
    case extraversion = "Extraversion"
    case agreeableness = "Agreeableness"
    case neuroticism = "Neuroticism"

    var id: String { rawValue }

    var definition: PersonalityTraitDefinition {
        PersonalityAssessmentCatalog.definition.traitDefinition(for: self)
    }

    var symbolName: String { definition.symbolName }

    func bandLabel(for score: Double) -> String {
        definition.band(for: score).label
    }

    func explanation(for score: Double) -> String {
        definition.band(for: score).interpretation
    }
}

struct PersonalityTraitDefinition: Identifiable {
    var id: String { trait.rawValue }

    let trait: PersonalityTrait
    let symbolName: String
    let bands: [PersonalityScoreBand]

    func band(for score: Double) -> PersonalityScoreBand {
        bands.first { $0.contains(score) } ?? bands[bands.count / 2]
    }
}

struct PersonalityScoreBand: Identifiable {
    var id: String { "\(label)-\(range.lowerBound)-\(range.upperBound)" }

    let label: String
    let range: ClosedRange<Double>
    let interpretation: String

    func contains(_ score: Double) -> Bool {
        score >= range.lowerBound && score <= range.upperBound
    }
}

struct PersonalityAnswerScale {
    let minimumValue: Int
    let maximumValue: Int
    let minimumLabel: String
    let maximumLabel: String
    let answers: [Int]
}

struct PersonalityAssessmentDefinition {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let description: String
    let disclaimer: String
    let questions: [PersonalityQuestion]
    let answerScale: PersonalityAnswerScale
    let traits: [PersonalityTraitDefinition]
    let resultTitle: String
    let interpretation: String
    let saveButtonTitle: String
    let savedButtonTitle: String
    let recommendedNextSteps: [AssessmentNextStep]

    func traitDefinition(for trait: PersonalityTrait) -> PersonalityTraitDefinition {
        guard let definition = traits.first(where: { $0.trait == trait }) else {
            preconditionFailure("Missing personality trait definition for \(trait.rawValue)")
        }

        return definition
    }
}

struct PersonalityQuestion: Identifiable {
    let id: Int
    let trait: PersonalityTrait
    let text: String
    let isReverseScored: Bool

    func scoredValue(for answer: Int, answerScale: PersonalityAnswerScale) -> Int {
        isReverseScored ? answerScale.minimumValue + answerScale.maximumValue - answer : answer
    }
}

struct PersonalityResults: Equatable {
    let opennessScore: Double
    let conscientiousnessScore: Double
    let extraversionScore: Double
    let agreeablenessScore: Double
    let neuroticismScore: Double

    func score(for trait: PersonalityTrait) -> Double {
        switch trait {
        case .openness:
            return opennessScore
        case .conscientiousness:
            return conscientiousnessScore
        case .extraversion:
            return extraversionScore
        case .agreeableness:
            return agreeablenessScore
        case .neuroticism:
            return neuroticismScore
        }
    }

    var averageScore: Double {
        let scores = PersonalityTrait.allCases.map { score(for: $0) }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var highestTraits: [PersonalityTrait] {
        let maximumScore = PersonalityTrait.allCases.map { score(for: $0) }.max() ?? 0
        return PersonalityTrait.allCases.filter { abs(score(for: $0) - maximumScore) < 0.5 }
    }

    var lowestTraits: [PersonalityTrait] {
        let minimumScore = PersonalityTrait.allCases.map { score(for: $0) }.min() ?? 0
        return PersonalityTrait.allCases.filter { abs(score(for: $0) - minimumScore) < 0.5 }
    }

    var patternSummary: String {
        let highText = highestTraits.map(\.rawValue).joined(separator: ", ")
        let lowText = lowestTraits.map(\.rawValue).joined(separator: ", ")
        return "Your strongest relative signal is \(highText). Your lowest relative signal is \(lowText). Treat these as conversation starters for self-reflection, not fixed labels."
    }
}

enum PersonalityAssessmentCatalog {
    static let definition = PersonalityAssessmentDefinition(
        id: "big-five",
        title: "Big Five",
        subtitle: "OCEAN self-discovery snapshot",
        symbolName: "person.crop.circle.badge.questionmark",
        description: "A compact OCEAN snapshot for self-reflection: Openness, Conscientiousness, Extraversion, Agreeableness, and Neuroticism.",
        disclaimer: "This assessment is for self-discovery and entertainment purposes only. It is not a diagnosis, psychological evaluation, or clinical evaluation.",
        questions: [
            PersonalityQuestion(id: 0, trait: .extraversion, text: "I am someone who is outgoing, sociable.", isReverseScored: false),
            PersonalityQuestion(id: 1, trait: .extraversion, text: "I am someone who is reserved, quiet.", isReverseScored: true),
            PersonalityQuestion(id: 2, trait: .agreeableness, text: "I am someone who is generally trusting.", isReverseScored: false),
            PersonalityQuestion(id: 3, trait: .agreeableness, text: "I am someone who tends to find fault with others.", isReverseScored: true),
            PersonalityQuestion(id: 4, trait: .conscientiousness, text: "I am someone who does a thorough job.", isReverseScored: false),
            PersonalityQuestion(id: 5, trait: .conscientiousness, text: "I am someone who tends to be lazy or easily distracted.", isReverseScored: true),
            PersonalityQuestion(id: 6, trait: .neuroticism, text: "I am someone who is relaxed, handles stress well.", isReverseScored: true),
            PersonalityQuestion(id: 7, trait: .neuroticism, text: "I am someone who gets nervous easily.", isReverseScored: false),
            PersonalityQuestion(id: 8, trait: .openness, text: "I am someone who has an active imagination.", isReverseScored: false),
            PersonalityQuestion(id: 9, trait: .openness, text: "I am someone who has relatively few artistic interests.", isReverseScored: true)
        ],
        answerScale: PersonalityAnswerScale(
            minimumValue: 1,
            maximumValue: 5,
            minimumLabel: "Disagree strongly",
            maximumLabel: "Agree strongly",
            answers: Array(1...5)
        ),
        traits: [
            PersonalityTraitDefinition(
                trait: .openness,
                symbolName: "sparkles",
                bands: [
                    PersonalityScoreBand(label: "Lower", range: 0...34.99, interpretation: "Lower scores can reflect preference for familiarity, practicality, and concrete routines."),
                    PersonalityScoreBand(label: "Middle", range: 35...65.99, interpretation: "Middle scores often reflect flexibility: this trait may show up more strongly in some contexts than others."),
                    PersonalityScoreBand(label: "Higher", range: 66...100, interpretation: "Higher scores often reflect imagination, curiosity, and comfort with novelty.")
                ]
            ),
            PersonalityTraitDefinition(
                trait: .conscientiousness,
                symbolName: "checkmark.seal",
                bands: [
                    PersonalityScoreBand(label: "Lower", range: 0...34.99, interpretation: "Lower scores can reflect flexibility, spontaneity, and less emphasis on structure."),
                    PersonalityScoreBand(label: "Middle", range: 35...65.99, interpretation: "Middle scores often reflect flexibility: this trait may show up more strongly in some contexts than others."),
                    PersonalityScoreBand(label: "Higher", range: 66...100, interpretation: "Higher scores often reflect organization, follow-through, and careful effort.")
                ]
            ),
            PersonalityTraitDefinition(
                trait: .extraversion,
                symbolName: "person.2",
                bands: [
                    PersonalityScoreBand(label: "Lower", range: 0...34.99, interpretation: "Lower scores can reflect reserved energy, quiet focus, and comfort with solitude."),
                    PersonalityScoreBand(label: "Middle", range: 35...65.99, interpretation: "Middle scores often reflect flexibility: this trait may show up more strongly in some contexts than others."),
                    PersonalityScoreBand(label: "Higher", range: 66...100, interpretation: "Higher scores often reflect social energy, assertiveness, and stimulation seeking.")
                ]
            ),
            PersonalityTraitDefinition(
                trait: .agreeableness,
                symbolName: "heart",
                bands: [
                    PersonalityScoreBand(label: "Lower", range: 0...34.99, interpretation: "Lower scores can reflect directness, skepticism, and stronger personal boundaries."),
                    PersonalityScoreBand(label: "Middle", range: 35...65.99, interpretation: "Middle scores often reflect flexibility: this trait may show up more strongly in some contexts than others."),
                    PersonalityScoreBand(label: "Higher", range: 66...100, interpretation: "Higher scores often reflect trust, cooperation, and warmth toward others.")
                ]
            ),
            PersonalityTraitDefinition(
                trait: .neuroticism,
                symbolName: "waveform.path.ecg",
                bands: [
                    PersonalityScoreBand(label: "Lower", range: 0...34.99, interpretation: "Lower scores can reflect steadiness, stress tolerance, and emotional calm."),
                    PersonalityScoreBand(label: "Middle", range: 35...65.99, interpretation: "Middle scores often reflect flexibility: this trait may show up more strongly in some contexts than others."),
                    PersonalityScoreBand(label: "Higher", range: 66...100, interpretation: "Higher scores often reflect more emotional sensitivity and stress reactivity.")
                ]
            )
        ],
        resultTitle: "Trait Overview",
        interpretation: "Scores are rough 0-100 trait estimates from a compact 10-prompt reflection. Higher does not mean better, and lower does not mean worse. Each trait can be useful or costly depending on the situation.",
        saveButtonTitle: "Save Reflection",
        savedButtonTitle: "Saved",
        recommendedNextSteps: [
            AssessmentNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Turn the snapshot into a short reflection.", symbolName: "pencil.and.list.clipboard", destination: .guidedJournal),
            AssessmentNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Plan a task that fits your energy and style.", symbolName: "calendar.badge.clock", destination: .activityPlanner),
            AssessmentNextStep(id: "exercises", title: "Exercises", subtitle: "Browse coping tools that match what you noticed.", symbolName: "figure.mind.and.body", destination: .exercises)
        ]
    )
}

enum PersonalityAssessmentEngine {
    static var questions: [PersonalityQuestion] {
        PersonalityAssessmentCatalog.definition.questions
    }

    static func results(from answers: [Int?]) -> PersonalityResults? {
        let definition = PersonalityAssessmentCatalog.definition
        guard answers.count == definition.questions.count, answers.allSatisfy({ $0 != nil }) else {
            return nil
        }

        var rawScores: [PersonalityTrait: Int] = [:]

        for question in definition.questions {
            guard let answer = answers[question.id] else { return nil }
            rawScores[question.trait, default: 0] += question.scoredValue(for: answer, answerScale: definition.answerScale)
        }

        return PersonalityResults(
            opennessScore: percentage(fromTwoItemRawScore: rawScores[.openness, default: 0]),
            conscientiousnessScore: percentage(fromTwoItemRawScore: rawScores[.conscientiousness, default: 0]),
            extraversionScore: percentage(fromTwoItemRawScore: rawScores[.extraversion, default: 0]),
            agreeablenessScore: percentage(fromTwoItemRawScore: rawScores[.agreeableness, default: 0]),
            neuroticismScore: percentage(fromTwoItemRawScore: rawScores[.neuroticism, default: 0])
        )
    }

    private static func percentage(fromTwoItemRawScore rawScore: Int) -> Double {
        let clamped = min(10, max(2, rawScore))
        return (Double(clamped - 2) / 8.0) * 100.0
    }
}
