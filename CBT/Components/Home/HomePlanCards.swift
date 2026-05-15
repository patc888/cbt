import SwiftUI

struct MoodCheckInPlanCard: View {
    let completionState: PlanCardCompletionState
    let action: () -> Void
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        PlanCard(
            title: String(localized: "Mood Check-In"),
            subtitle: String(localized: "Capture how you feel right now."),
            trailingSymbol: "face.smiling",
            completionState: completionState
        ) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Start quick check-in"))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                        Text(String(localized: "Takes about 1 minute"))
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(themeManager.selectedColor)
                }
                .padding(.top, 12)
            }
        } action: {
            action()
        }
        .accessibilityIdentifier("home-plan-mood-check-in")
    }
}

struct ThoughtRecordPlanCard: View {
    let completionState: PlanCardCompletionState
    let action: () -> Void

    var body: some View {
        PlanCard(
            title: String(localized: "Thought Record"),
            subtitle: String(localized: "Challenge one difficult thought."),
            trailingSymbol: "brain",
            completionState: completionState
        ) {
            action()
        }
    }
}

struct ExercisesPlanCard: View {
    let completionState: PlanCardCompletionState
    let action: () -> Void

    var body: some View {
        PlanCard(
            title: String(localized: "Exercises"),
            subtitle: String(localized: "Practice one CBT tool."),
            trailingSymbol: "figure.mind.and.body",
            completionState: completionState
        ) {
            action()
        }
    }
}

struct BreathingResetPlanCard: View {
    let completionState: PlanCardCompletionState
    let action: () -> Void

    var body: some View {
        PlanCard(
            title: String(localized: "Breathing Reset"),
            subtitle: String(localized: "Calm your body in 60 seconds"),
            trailingSymbol: "wind",
            completionState: completionState
        ) {
            action()
        }
    }
}

struct TipOfTheDayPlanCard: View {
    let completionState: PlanCardCompletionState
    let action: () -> Void

    var body: some View {
        PlanCard(
            title: String(localized: "Tip of the Day"),
            subtitle: String(localized: "Open a quick CBT reminder."),
            trailingSymbol: "lightbulb",
            completionState: completionState
        ) {
            action()
        }
    }
}
