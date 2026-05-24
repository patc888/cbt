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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(DailyPlanPersonalizationKeys.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(DailyPlanPersonalizationKeys.goals) private var savedGoals = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var savedInterests = ""

    @State private var selectedPage = 0
    @State private var selectedGoals: Set<DailyPlanGoal> = []
    @State private var selectedInterests: Set<DailyPlanInterest> = []

    private let pageCount = 5

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                TabView(selection: $selectedPage) {
                    OnboardingInfoPage(
                        systemImage: "brain.head.profile",
                        title: "CBT for Self-Help",
                        message: "CBT helps you notice thoughts, feelings, body cues, and actions, then practice small skills that may make the next step easier."
                    )
                    .tag(0)

                    OnboardingInfoPage(
                        systemImage: "lock.shield.fill",
                        title: "Private by Design",
                        message: "Your check-ins, journals, and plans stay in your app data. When iCloud sync is available, it uses your private iCloud account."
                    )
                    .tag(1)

                    OnboardingInfoPage(
                        systemImage: "face.smiling",
                        title: "Gentle Check-Ins",
                        message: "Check-ins are quick snapshots. They can help the app show patterns over time, and you can use them at your own pace."
                    )
                    .tag(2)

                    OnboardingInfoPage(
                        systemImage: "cross.case.fill",
                        title: "Not Emergency Care",
                        message: "This app can support self-reflection and coping practice, but it is not crisis care. If you may be in immediate danger, contact local emergency services now."
                    )
                    .tag(3)

                    personalizePage
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 4)

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

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? themeManager.selectedColor : Theme.tertiaryText.opacity(0.28))
                    .frame(width: index == selectedPage ? 22 : 7, height: 7)
                    .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.25, dampingFraction: 0.8), value: selectedPage)
            }
        }
        .accessibilityHidden(true)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            Button {
                if selectedPage == pageCount - 1 {
                    completeOnboarding()
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedPage += 1
                    }
                }
            } label: {
                Label(selectedPage == pageCount - 1 ? "Start" : "Next", systemImage: selectedPage == pageCount - 1 ? "checkmark.circle.fill" : "arrow.right")
            }
            .buttonStyle(DSPrimaryButtonStyle())

            Button {
                completeOnboarding()
            } label: {
                Text("Skip for Now")
                    .font(DSTypography.button)
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
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
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(isSelected ? .white : Theme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(isSelected ? themeManager.selectedColor : DSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : Theme.secondaryText.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

private struct OnboardingInfoPage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack {
            Spacer(minLength: 24)
            OnboardingHeader(systemImage: systemImage, title: title, message: message)
                .padding(.horizontal, 28)
            Spacer(minLength: 24)
        }
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
