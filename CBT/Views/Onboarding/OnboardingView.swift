import SwiftUI
import SwiftData
import OSLog

enum DailyPlanPersonalizationKeys {
    static let onboardingCompleted = "cbt_onboardingCompleted"
    static let goals = "cbt_dailyPlanGoalIDs"
    static let interests = "cbt_dailyPlanInterestIDs"
    static let sessionLength = "cbt_dailyPlanPreferredSessionLength"
    static let daypart = "cbt_dailyPlanPreferredDaypart"
    static let commonTriggers = "cbt_dailyPlanCommonTriggerIDs"
    static let helpfulInterventions = "cbt_dailyPlanHelpfulInterventionIDs"
    static let onboardingReasons = "cbt_onboardingReasonIDs"
    static let therapistStatus = "cbt_onboardingTherapistStatus"
    static let hardSituations = "cbt_onboardingHardSituationIDs"
    static let twoWeekProgress = "cbt_onboardingTwoWeekProgress"
    static let baselineAssessmentInterests = "cbt_onboardingBaselineAssessmentInterests"
    static let openAssessmentsAfterOnboarding = "cbt_openAssessmentsAfterOnboarding"
    static let structure = "cbt_dailyPlanStructurePreference"
    static let avoidances = "cbt_dailyPlanAvoidanceIDs"
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

enum DailyPlanSessionLength: String, CaseIterable, Identifiable {
    case quick = "quick"
    case standard = "standard"
    case deeper = "deeper"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "1-3 min"
        case .standard: return "5-8 min"
        case .deeper: return "10+ min"
        }
    }
}

enum DailyPlanDaypart: String, CaseIterable, Identifiable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

enum DailyPlanCommonTrigger: String, CaseIterable, Identifiable {
    case work = "work"
    case relationships = "relationships"
    case sleep = "sleep"
    case uncertainty = "uncertainty"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "Work or school"
        case .relationships: return "Relationships"
        case .sleep: return "Sleep or energy"
        case .uncertainty: return "Uncertainty"
        }
    }
}

enum DailyPlanHelpfulIntervention: String, CaseIterable, Identifiable {
    case breathing = "breathing"
    case journaling = "journaling"
    case thoughtRecord = "thought_record"
    case activity = "activity"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathing: return "Breathing"
        case .journaling: return "Journaling"
        case .thoughtRecord: return "Thought checks"
        case .activity: return "Tiny actions"
        }
    }
}

enum OnboardingReason: String, CaseIterable, Identifiable {
    case anxiety = "anxiety"
    case lowMood = "low_mood"
    case stress = "stress"
    case relationships = "relationships"
    case habits = "habits"
    case selfUnderstanding = "self_understanding"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anxiety: return "Anxiety or worry"
        case .lowMood: return "Low mood"
        case .stress: return "Stress"
        case .relationships: return "Relationships"
        case .habits: return "Habits and routines"
        case .selfUnderstanding: return "Self-understanding"
        }
    }
}

enum TherapistSupportStatus: String, CaseIterable, Identifiable {
    case yes = "yes"
    case no = "no"
    case considering = "considering"
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .considering: return "Considering it"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum HardSituation: String, CaseIterable, Identifiable {
    case mornings = "mornings"
    case workOrSchool = "work_or_school"
    case social = "social"
    case conflict = "conflict"
    case evenings = "evenings"
    case uncertainty = "uncertainty"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mornings: return "Mornings"
        case .workOrSchool: return "Work or school"
        case .social: return "Social moments"
        case .conflict: return "Conflict"
        case .evenings: return "Evenings"
        case .uncertainty: return "Uncertainty"
        }
    }
}

enum DailyPlanStructurePreference: String, CaseIterable, Identifiable {
    case light = "light"
    case balanced = "balanced"
    case structured = "structured"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light touch"
        case .balanced: return "A simple plan"
        case .structured: return "Clear steps"
        }
    }
}

enum DailyPlanAvoidancePreference: String, CaseIterable, Identifiable {
    case tooManyReminders = "too_many_reminders"
    case pressure = "pressure"
    case longSessions = "long_sessions"
    case crowdedPlans = "crowded_plans"
    case clinicalLanguage = "clinical_language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooManyReminders: return "Too many reminders"
        case .pressure: return "Pressure or streak guilt"
        case .longSessions: return "Long sessions"
        case .crowdedPlans: return "Crowded plans"
        case .clinicalLanguage: return "Clinical language"
        }
    }
}

struct OnboardingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext

    @AppStorage(DailyPlanPersonalizationKeys.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(DailyPlanPersonalizationKeys.goals) private var savedGoals = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var savedInterests = ""
    @AppStorage(DailyPlanPersonalizationKeys.sessionLength) private var savedSessionLength = ""
    @AppStorage(DailyPlanPersonalizationKeys.daypart) private var savedDaypart = ""
    @AppStorage(DailyPlanPersonalizationKeys.commonTriggers) private var savedCommonTriggers = ""
    @AppStorage(DailyPlanPersonalizationKeys.helpfulInterventions) private var savedHelpfulInterventions = ""
    @AppStorage(DailyPlanPersonalizationKeys.onboardingReasons) private var savedOnboardingReasons = ""
    @AppStorage(DailyPlanPersonalizationKeys.therapistStatus) private var savedTherapistStatus = ""
    @AppStorage(DailyPlanPersonalizationKeys.hardSituations) private var savedHardSituations = ""
    @AppStorage(DailyPlanPersonalizationKeys.twoWeekProgress) private var savedTwoWeekProgress = ""
    @AppStorage(DailyPlanPersonalizationKeys.baselineAssessmentInterests) private var savedBaselineAssessmentInterests = ""
    @AppStorage(DailyPlanPersonalizationKeys.openAssessmentsAfterOnboarding) private var openAssessmentsAfterOnboarding = false
    @AppStorage(DailyPlanPersonalizationKeys.structure) private var savedStructure = ""
    @AppStorage(DailyPlanPersonalizationKeys.avoidances) private var savedAvoidances = ""

    @State private var selectedGoals: Set<DailyPlanGoal> = []
    @State private var selectedInterests: Set<DailyPlanInterest> = []
    @State private var selectedSessionLength: DailyPlanSessionLength?
    @State private var selectedDaypart: DailyPlanDaypart?
    @State private var selectedCommonTriggers: Set<DailyPlanCommonTrigger> = []
    @State private var selectedHelpfulInterventions: Set<DailyPlanHelpfulIntervention> = []
    @State private var selectedStructure: DailyPlanStructurePreference?
    @State private var selectedAvoidances: Set<DailyPlanAvoidancePreference> = []
    @State private var selectedValueIDs: Set<String> = []
    @State private var selectedReasons: Set<OnboardingReason> = []
    @State private var therapistStatus: TherapistSupportStatus = .preferNotToSay
    @State private var selectedHardSituations: Set<HardSituation> = []
    @State private var twoWeekProgress = ""
    @State private var selectedBaselineAssessments: Set<AssessmentKind> = []
    @State private var phase: OnboardingPhase = .privacy
    @State private var selectedFirstWin: FirstSessionWinKind = .moodCheckIn
    @State private var onboardingError: String?
    @State private var reminderPromptMoment: ReminderOptInMoment?
    @State private var isHandlingReminderPrompt = false

    private enum OnboardingPhase {
        case privacy
        case preferences
        case baseline
        case guidance
        case firstWin
        case success(FirstSessionWinKind?)
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                currentPage

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .responsiveMaxWidth()
        }
        .onAppear {
            LocalRetentionEventStore.shared.recordOnce(.onboardingStarted, sourceScreen: "onboarding")
        }
        .sheet(item: $reminderPromptMoment) { moment in
            ReminderOptInPromptView(
                moment: moment,
                isWorking: isHandlingReminderPrompt,
                onAccept: {
                    handleReminderPromptAccepted(moment)
                },
                onDismiss: {
                    handleReminderPromptDismissed(moment)
                }
            )
            .padding()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch phase {
        case .privacy:
            PrivacyWalkthroughView()
        case .preferences:
            personalizePage
        case .baseline:
            baselinePage
        case .guidance:
            guidancePage
        case .firstWin:
            firstWinPage
        case .success(let completion):
            successPage(completion: completion)
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

                optionGroup(title: "Session Length") {
                    ForEach(DailyPlanSessionLength.allCases) { length in
                        optionChip(
                            title: length.title,
                            isSelected: selectedSessionLength == length
                        ) {
                            toggleSessionLength(length)
                        }
                    }
                }

                optionGroup(title: "Best Time") {
                    ForEach(DailyPlanDaypart.allCases) { daypart in
                        optionChip(
                            title: daypart.title,
                            isSelected: selectedDaypart == daypart
                        ) {
                            toggleDaypart(daypart)
                        }
                    }
                }

                optionGroup(title: "Common Triggers") {
                    ForEach(DailyPlanCommonTrigger.allCases) { trigger in
                        optionChip(
                            title: trigger.title,
                            isSelected: selectedCommonTriggers.contains(trigger)
                        ) {
                            toggleCommonTrigger(trigger)
                        }
                    }
                }

                optionGroup(title: "What Helps") {
                    ForEach(DailyPlanHelpfulIntervention.allCases) { intervention in
                        optionChip(
                            title: intervention.title,
                            isSelected: selectedHelpfulInterventions.contains(intervention)
                        ) {
                            toggleHelpfulIntervention(intervention)
                        }
                    }
                }

                optionGroup(title: "How much structure feels good?") {
                    ForEach(DailyPlanStructurePreference.allCases) { preference in
                        optionChip(
                            title: preference.title,
                            isSelected: selectedStructure == preference
                        ) {
                            toggleStructure(preference)
                        }
                    }
                }

                optionGroup(title: "What should the app avoid doing?") {
                    ForEach(DailyPlanAvoidancePreference.allCases) { preference in
                        optionChip(
                            title: preference.title,
                            isSelected: selectedAvoidances.contains(preference)
                        ) {
                            toggleAvoidance(preference)
                        }
                    }
                }

                optionGroup(title: "Values") {
                    ForEach(ValuesService.defaultValues) { value in
                        optionChip(
                            title: value.name,
                            isSelected: selectedValueIDs.contains(value.id)
                        ) {
                            toggleValue(value)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }

    private var baselinePage: some View {
        ScrollView {
            VStack(spacing: 18) {
                OnboardingHeader(
                    systemImage: "person.text.rectangle.fill",
                    title: "Set your starting point",
                    message: "Answer what feels useful. This helps the app suggest gentler, more relevant first steps."
                )

                optionGroup(title: "What brings you here?") {
                    ForEach(OnboardingReason.allCases) { reason in
                        optionChip(
                            title: reason.title,
                            isSelected: selectedReasons.contains(reason)
                        ) {
                            toggleReason(reason)
                        }
                    }
                }

                optionGroup(title: "Are you working with a therapist?") {
                    ForEach(TherapistSupportStatus.allCases) { status in
                        optionChip(
                            title: status.title,
                            isSelected: therapistStatus == status
                        ) {
                            HapticManager.shared.selection()
                            therapistStatus = status
                        }
                    }
                }

                optionGroup(title: "What situations are hardest?") {
                    ForEach(HardSituation.allCases) { situation in
                        optionChip(
                            title: situation.title,
                            isSelected: selectedHardSituations.contains(situation)
                        ) {
                            toggleHardSituation(situation)
                        }
                    }
                }

                progressReflectionEditor

                baselineAssessmentPrompt
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            switch phase {
            case .privacy:
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        phase = .preferences
                    }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())

            case .preferences:
                Button {
                    savePreferences()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        phase = .baseline
                    }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button {
                    savePreferences()
                    FirstSessionWinService.skip()
                    showSuccess(nil)
                } label: {
                    Text("Skip for Now")
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))

            case .baseline:
                Button {
                    saveBaseline()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        phase = .guidance
                    }
                } label: {
                    Label("Continue", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button {
                    saveBaseline()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        phase = .guidance
                    }
                } label: {
                    Text("Skip This Step")
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))

            case .guidance:
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        phase = .firstWin
                    }
                } label: {
                    Label("Choose a First Step", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button {
                    FirstSessionWinService.skip()
                    showSuccess(nil)
                } label: {
                    Text("Skip This Step")
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))

            case .firstWin:
                Button {
                    completeFirstWin()
                } label: {
                    Label(firstWinActionTitle, systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())

                Button {
                    FirstSessionWinService.skip()
                    showSuccess(nil)
                } label: {
                    Text("Skip This Step")
                }
                .buttonStyle(DSSecondaryButtonStyle(size: .medium))

            case .success:
                Button {
                    completeOnboarding()
                } label: {
                    Label("Enter App", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(DSPrimaryButtonStyle())
            }
        }
    }

    private var guidancePage: some View {
        ScrollView {
            VStack(spacing: 18) {
                OnboardingHeader(
                    systemImage: "arrow.triangle.2.circlepath.circle.fill",
                    title: "How CBT helps",
                    message: "You do not need to use everything at once. Most days, one simple loop is enough."
                )

                VStack(spacing: 10) {
                    guidanceStep(
                        number: "1",
                        systemImage: "face.smiling",
                        title: "Check in",
                        message: "Name your mood, energy, and what is happening around you."
                    )

                    guidanceStep(
                        number: "2",
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Notice a pattern",
                        message: "Your Daily Plan and insights help connect moments, triggers, thoughts, and habits."
                    )

                    guidanceStep(
                        number: "3",
                        systemImage: "sparkle.magnifyingglass",
                        title: "Try one tool, then reflect",
                        message: "Use a short CBT practice, breathing reset, journal prompt, or thought record. Then see what shifted."
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }

    private var progressReflectionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What would progress look like in 2 weeks?")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            ZStack(alignment: .topLeading) {
                if twoWeekProgress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Example: fewer spirals at night, asking for help sooner, or doing one tiny routine most days.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $twoWeekProgress)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .frame(minHeight: 112)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DSTheme.separator.opacity(0.7), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var baselineAssessmentPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Optional baseline", systemImage: "checklist")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text("GAD-7 and PHQ-8 can give you a simple anxiety and mood starting point to compare against later. They are tracking tools, not diagnoses.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            VStack(spacing: 10) {
                baselineAssessmentOption(.gad7, subtitle: "Track anxiety-related symptoms over the past two weeks.")
                baselineAssessmentOption(.phq8, subtitle: "Track mood-related symptoms over the past two weeks.")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private func baselineAssessmentOption(_ kind: AssessmentKind, subtitle: String) -> some View {
        Button {
            HapticManager.shared.selection()
            toggleBaselineAssessment(kind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Image(systemName: selectedBaselineAssessments.contains(kind) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedBaselineAssessments.contains(kind) ? themeManager.selectedColor : Theme.secondaryText)
            }
            .padding(12)
            .background(
                themeManager.selectedColor.opacity(selectedBaselineAssessments.contains(kind) ? 0.1 : 0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedBaselineAssessments.contains(kind) ? .isSelected : [])
    }

    private var firstWinPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                OnboardingHeader(
                    systemImage: "checkmark.seal.fill",
                    title: "Start with one small win",
                    message: "Pick one quick action before you enter the app. The mood check-in is recommended because it gives Today's Plan a useful starting point."
                )

                if let onboardingError {
                    Text(onboardingError)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach([FirstSessionWinKind.moodCheckIn, .breathing, .todaysPlan]) { kind in
                        firstWinOption(kind)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 12)
        }
    }

    private func guidanceStep(number: String, systemImage: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 44, height: 44)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                Text(number)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(themeManager.selectedColor, in: Circle())
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private func firstWinOption(_ kind: FirstSessionWinKind) -> some View {
        Button {
            HapticManager.shared.selection()
            selectedFirstWin = kind
        } label: {
            HStack(spacing: 12) {
                Image(systemName: firstWinSystemImage(for: kind))
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(firstWinTitle(for: kind))
                            .font(.system(.headline, design: .rounded).weight(.bold))

                        if kind == .moodCheckIn {
                            Text("Recommended")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.selectedColor.opacity(0.14), in: Capsule())
                        }
                    }
                    .foregroundStyle(Theme.primaryText)

                    Text(firstWinSubtitle(for: kind))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: selectedFirstWin == kind ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFirstWin == kind ? themeManager.selectedColor : Theme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selectedFirstWin == kind ? themeManager.selectedColor.opacity(0.5) : DSTheme.separator.opacity(0.7),
                        lineWidth: selectedFirstWin == kind ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedFirstWin == kind ? .isSelected : [])
    }

    private func successPage(completion: FirstSessionWinKind?) -> some View {
        let message: String = {
            switch completion {
            case .moodCheckIn:
                return "Your first check-in is saved for today."
            case .breathing:
                return "Your breathing reset is logged for today's plan."
            case .todaysPlan:
                return "Today's plan has one small step ready."
            case .existingActivity:
                return "Your progress is ready for today."
            case nil:
                return "You can start with any small step when you are ready."
            }
        }()

        return VStack(spacing: 18) {
            Spacer(minLength: 24)

            OnboardingHeader(
                systemImage: completion == nil ? "sparkles" : "checkmark.seal.fill",
                title: completion == nil ? "You're ready" : "Nice first step",
                message: message
            )

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }

    private var firstWinActionTitle: String {
        switch selectedFirstWin {
        case .moodCheckIn: return "Save Check-In"
        case .breathing: return "Log Breathing Reset"
        case .todaysPlan: return "Build Today's Plan"
        case .existingActivity: return "Continue"
        }
    }

    private func firstWinTitle(for kind: FirstSessionWinKind) -> String {
        switch kind {
        case .moodCheckIn: return "Mood check-in"
        case .breathing: return "60-second breathing reset"
        case .todaysPlan: return "Build today's plan"
        case .existingActivity: return "Use existing progress"
        }
    }

    private func firstWinSubtitle(for kind: FirstSessionWinKind) -> String {
        switch kind {
        case .moodCheckIn: return "Name how you are arriving today."
        case .breathing: return "Take one steady minute before you begin."
        case .todaysPlan: return "Set one small step for today."
        case .existingActivity: return "Keep going with what you already started."
        }
    }

    private func firstWinSystemImage(for kind: FirstSessionWinKind) -> String {
        switch kind {
        case .moodCheckIn: return "face.smiling"
        case .breathing: return "wind"
        case .todaysPlan: return "list.bullet.clipboard.fill"
        case .existingActivity: return "checkmark.seal.fill"
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

    private func toggleSessionLength(_ length: DailyPlanSessionLength) {
        HapticManager.shared.selection()
        selectedSessionLength = selectedSessionLength == length ? nil : length
    }

    private func toggleDaypart(_ daypart: DailyPlanDaypart) {
        HapticManager.shared.selection()
        selectedDaypart = selectedDaypart == daypart ? nil : daypart
    }

    private func toggleCommonTrigger(_ trigger: DailyPlanCommonTrigger) {
        HapticManager.shared.selection()
        if selectedCommonTriggers.contains(trigger) {
            selectedCommonTriggers.remove(trigger)
        } else {
            selectedCommonTriggers.insert(trigger)
        }
    }

    private func toggleHelpfulIntervention(_ intervention: DailyPlanHelpfulIntervention) {
        HapticManager.shared.selection()
        if selectedHelpfulInterventions.contains(intervention) {
            selectedHelpfulInterventions.remove(intervention)
        } else {
            selectedHelpfulInterventions.insert(intervention)
        }
    }

    private func toggleStructure(_ preference: DailyPlanStructurePreference) {
        HapticManager.shared.selection()
        selectedStructure = selectedStructure == preference ? nil : preference
    }

    private func toggleAvoidance(_ preference: DailyPlanAvoidancePreference) {
        HapticManager.shared.selection()
        if selectedAvoidances.contains(preference) {
            selectedAvoidances.remove(preference)
        } else {
            selectedAvoidances.insert(preference)
        }
    }

    private func toggleValue(_ value: ValueDefinition) {
        HapticManager.shared.selection()
        if selectedValueIDs.contains(value.id) {
            selectedValueIDs.remove(value.id)
        } else {
            selectedValueIDs.insert(value.id)
        }
    }

    private func toggleReason(_ reason: OnboardingReason) {
        HapticManager.shared.selection()
        if selectedReasons.contains(reason) {
            selectedReasons.remove(reason)
        } else {
            selectedReasons.insert(reason)
        }
    }

    private func toggleHardSituation(_ situation: HardSituation) {
        HapticManager.shared.selection()
        if selectedHardSituations.contains(situation) {
            selectedHardSituations.remove(situation)
        } else {
            selectedHardSituations.insert(situation)
        }
    }

    private func toggleBaselineAssessment(_ kind: AssessmentKind) {
        if selectedBaselineAssessments.contains(kind) {
            selectedBaselineAssessments.remove(kind)
        } else {
            selectedBaselineAssessments.insert(kind)
        }
    }

    private func savePreferences() {
        savedGoals = DailyPlanGoal.allCases
            .filter { selectedGoals.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        savedInterests = DailyPlanInterest.allCases
            .filter { selectedInterests.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        savedSessionLength = selectedSessionLength?.rawValue ?? ""
        savedDaypart = selectedDaypart?.rawValue ?? ""
        savedCommonTriggers = DailyPlanCommonTrigger.allCases
            .filter { selectedCommonTriggers.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        savedHelpfulInterventions = DailyPlanHelpfulIntervention.allCases
            .filter { selectedHelpfulInterventions.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        savedStructure = selectedStructure?.rawValue ?? ""
        savedAvoidances = DailyPlanAvoidancePreference.allCases
            .filter { selectedAvoidances.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")

        do {
            for value in ValuesService.defaultValues where selectedValueIDs.contains(value.id) {
                _ = try ValuesService.selectDefaultValue(value, in: modelContext)
            }
            onboardingError = nil
        } catch {
            onboardingError = "Your values did not save yet. You can add them later from Profile."
            AppLogger.make(category: "Onboarding").error("Failed to save onboarding values: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func saveBaseline() {
        savedOnboardingReasons = StringArrayStorage.encode(
            OnboardingReason.allCases
                .filter { selectedReasons.contains($0) }
                .map(\.rawValue)
        )
        savedTherapistStatus = therapistStatus.rawValue
        savedHardSituations = StringArrayStorage.encode(
            HardSituation.allCases
                .filter { selectedHardSituations.contains($0) }
                .map(\.rawValue)
        )
        savedTwoWeekProgress = twoWeekProgress.trimmingCharacters(in: .whitespacesAndNewlines)
        savedBaselineAssessmentInterests = StringArrayStorage.encode(
            [AssessmentKind.gad7, .phq8]
                .filter { selectedBaselineAssessments.contains($0) }
                .map(\.rawValue)
        )
        openAssessmentsAfterOnboarding = !selectedBaselineAssessments.isEmpty
    }

    private func completeFirstWin() {
        do {
            try FirstSessionWinService.complete(
                kind: selectedFirstWin,
                modelContext: modelContext
            )
            HapticManager.shared.success()
            showSuccess(selectedFirstWin)
        } catch {
            onboardingError = "That step did not save. You can try again or skip it for now."
            AppLogger.make(category: "Onboarding").error("Failed to save onboarding first win: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func showSuccess(_ completion: FirstSessionWinKind?) {
        onboardingError = nil
        switch completion {
        case .moodCheckIn:
            LocalRetentionEventStore.shared.recordOnce(.firstMoodCheckInCompleted, sourceScreen: "onboarding")
            LocalRetentionEventStore.shared.recordOnce(.firstDailyPlanItemCompleted, sourceScreen: "onboarding", metadata: ["item": "mood_check_in"])
        case .breathing:
            LocalRetentionEventStore.shared.recordOnce(.firstDailyPlanItemCompleted, sourceScreen: "onboarding", metadata: ["item": "breathing_reset"])
        case .todaysPlan:
            LocalRetentionEventStore.shared.recordOnce(.firstDailyPlanItemCompleted, sourceScreen: "onboarding", metadata: ["item": "activity_planner"])
        case .existingActivity:
            break
        case nil:
            LocalRetentionEventStore.shared.record(
                .onboardingSkipped,
                sourceScreen: "onboarding",
                metadata: [
                    "goal_count": "\(selectedGoals.count)",
                    "interest_count": "\(selectedInterests.count)",
                    "structure": selectedStructure?.rawValue ?? "none",
                    "avoidance_count": "\(selectedAvoidances.count)",
                    "baseline_assessment_count": "\(selectedBaselineAssessments.count)"
                ]
            )
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            phase = .success(completion)
        }

        guard completion != nil else { return }
        Task {
            reminderPromptMoment = await ReminderOptInService.shared.promptIfEligible(
                for: .onboardingFirstWin,
                hasReachedMoment: true
            )
        }
    }

    private func completeOnboarding() {
        LocalRetentionEventStore.shared.record(
            .onboardingCompleted,
            sourceScreen: "onboarding",
            metadata: [
                "goal_count": "\(selectedGoals.count)",
                "interest_count": "\(selectedInterests.count)",
                "structure": selectedStructure?.rawValue ?? "none",
                "avoidance_count": "\(selectedAvoidances.count)",
                "reason_count": "\(selectedReasons.count)",
                "hard_situation_count": "\(selectedHardSituations.count)",
                "therapist_status": therapistStatus.rawValue,
                "baseline_assessment_count": "\(selectedBaselineAssessments.count)"
            ]
        )
        onboardingCompleted = true
        if openAssessmentsAfterOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: .appTabSelectionRequested, object: FloatingTab.assessments)
            }
        }
    }

    private func handleReminderPromptAccepted(_ moment: ReminderOptInMoment) {
        guard !isHandlingReminderPrompt else { return }
        isHandlingReminderPrompt = true
        Task {
            _ = await ReminderOptInService.shared.accept(moment, modelContext: modelContext)
            await MainActor.run {
                reminderPromptMoment = nil
                isHandlingReminderPrompt = false
            }
        }
    }

    private func handleReminderPromptDismissed(_ moment: ReminderOptInMoment) {
        ReminderOptInService.shared.dismiss(moment)
        reminderPromptMoment = nil
    }
}

struct OnboardingHeader: View {
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
