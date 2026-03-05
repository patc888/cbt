import Foundation

enum SessionSourceKind: String, CaseIterable {
    case breathing = "breathing"
    case affirmation = "affirmation"
    case distortionExample = "distortionExample"
    case exercise = "exercise"

    var displayName: String {
        switch self {
        case .breathing: return "Breathing"
        case .affirmation: return "Affirmations"
        case .distortionExample: return "Distortion Practice"
        case .exercise: return "Exercise"
        }
    }

    var iconName: String {
        switch self {
        case .breathing: return "wind"
        case .affirmation: return "sparkles"
        case .distortionExample: return "brain.head.profile"
        case .exercise: return "figure.mind.and.body"
        }
    }
}

struct SessionSummary {
    var sourceKind: SessionSourceKind
    var sourceID: String
    var title: String
    var bodyText: String
    var durationSeconds: Int
    var startedAt: Date
    var endedAt: Date
}
