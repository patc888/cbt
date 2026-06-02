import SwiftUI

enum DailyPlanPersonalizationKeys {
    static let onboardingCompleted = "cbt_onboardingCompleted"
    static let goals = "cbt_dailyPlanGoalIDs"
    static let interests = "cbt_dailyPlanInterestIDs"
}

enum DailyPlanGoal: String, CaseIterable, Identifiable {
    case calm = "calm"
    case understandThoughts = "understand_thoughts"
    case trackMood = "track_mood"
    case buildRoutine = "build_routine"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm:
            return "Feel steadier"
        case .understandThoughts:
            return "Understand thoughts"
        case .trackMood:
            return "Track mood"
        case .buildRoutine:
            return "Build routine"
        }
    }

    var dailyPlanPhrase: String {
        switch self {
        case .calm:
            return "feeling a little steadier"
        case .understandThoughts:
            return "understanding thoughts with more space"
        case .trackMood:
            return "noticing mood patterns"
        case .buildRoutine:
            return "building a gentle routine"
        }
    }
}

enum DailyPlanInterest: String, CaseIterable, Identifiable {
    case breathing = "breathing"
    case thoughtRecords = "thought_records"
    case journaling = "journaling"
    case courses = "courses"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathing:
            return "Breathing"
        case .thoughtRecords:
            return "Thought records"
        case .journaling:
            return "Journaling"
        case .courses:
            return "Courses"
        }
    }
}

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager

    @AppStorage(DailyPlanPersonalizationKeys.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(DailyPlanPersonalizationKeys.goals) private var savedGoals = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var savedInterests = ""

    @State private var selectedGoals: Set<DailyPlanGoal> = []
    @State private var selectedInterests: Set<DailyPlanInterest> = []

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                personalizePage

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .responsiveMaxWidth()
        }
    }

    private var personalizePage: some View {
        ScrollView {
            VStack(spacing: 18) {
                OnboardingHeader(
                    systemImage: "slider.horizontal.3",
                    title: "Personalize Daily Plan",
                    message: "Choose any goals or interests that fit. This is optional and only adjusts the Daily Plan suggestions."
                )

                optionGroup(title: "Goals") {
                    ForEach(DailyPlanGoal.allCases) { goal in
                        optionChip(
                            title: goal.title,
                            isSelected: selectedGoals.contains(goal)
                        ) {
                            toggleGoal(goal)
                        }
                    }
                }

                optionGroup(title: "Interests") {
                    ForEach(DailyPlanInterest.allCases) { interest in
                        optionChip(
                            title: interest.title,
                            isSelected: selectedInterests.contains(interest)
                        ) {
                            toggleInterest(interest)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            Button {
                completeOnboarding()
            } label: {
                Label("Start", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(DSPrimaryButtonStyle())

            Button {
                completeOnboarding()
            } label: {
                Text("Skip for Now")
            }
            .buttonStyle(DSSecondaryButtonStyle(size: .medium))
        }
    }

    private func optionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 138), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                Text(title)
                    .lineLimit(2)
            }
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: isSelected, selectedColor: themeManager.selectedColor, size: .medium))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleGoal(_ goal: DailyPlanGoal) {
        HapticManager.shared.selection()
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    private func toggleInterest(_ interest: DailyPlanInterest) {
        HapticManager.shared.selection()
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
    }

    private func completeOnboarding() {
        savedGoals = DailyPlanGoal.allCases
            .filter { selectedGoals.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        savedInterests = DailyPlanInterest.allCases
            .filter { selectedInterests.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        onboardingCompleted = true
    }
}

private struct OnboardingHeader: View {
    @Environment(ThemeManager.self) private var themeManager

    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 96, height: 96)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(title)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
