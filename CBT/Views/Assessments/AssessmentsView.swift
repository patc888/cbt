import SwiftData
import SwiftUI

struct AssessmentsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \AssessmentLog.date, order: .reverse) private var logs: [AssessmentLog]
    @Query(sort: \PersonalityAssessmentLog.date, order: .reverse) private var personalityLogs: [PersonalityAssessmentLog]
    @State private var infoKind: AssessmentKind?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppScreenHeadline(title: "Assessments")

                        AssessmentDisclaimer()

                        AssessmentStartSection(
                            title: "Validated Trackers",
                            kinds: AssessmentKind.validatedTrackers
                        ) { kind in
                            infoKind = kind
                        }

                        AssessmentStartSection(
                            title: "Informational Check-Ins",
                            kinds: AssessmentKind.selfReflectionCheckIns
                        ) { kind in
                            infoKind = kind
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Self-Discovery")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)

                            NavigationLink {
                                PersonalityAssessmentView()
                            } label: {
                                SelfDiscoveryStartRow()
                            }
                            .buttonStyle(.plain)
                        }

                        AssessmentTrendsSection(logs: logs, personalityLogs: personalityLogs)
                    }
                    .dsContentLayout()
                    .padding(.bottom, 18)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
                }
            }
            .navigationDestination(for: AssessmentKind.self) { kind in
                AssessmentQuizView(kind: kind)
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .sheet(item: $infoKind) { kind in
            AssessmentInfoSheet(kind: kind)
        }
    }
}

private struct AssessmentStartSection: View {
    let title: String
    let kinds: [AssessmentKind]
    let infoAction: (AssessmentKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            ForEach(kinds) { kind in
                AssessmentStartRow(kind: kind) {
                    infoAction(kind)
                }
            }
        }
    }
}

private struct SelfDiscoveryStartRow: View {
    @Environment(ThemeManager.self) private var themeManager
    private let definition = PersonalityAssessmentCatalog.definition

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: definition.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 42, height: 42)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(definition.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(definition.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct AssessmentStartRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let kind: AssessmentKind
    let infoAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink(value: kind) {
                HStack(spacing: 14) {
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 42, height: 42)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(kind.subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                HapticManager.shared.selection()
                infoAction()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About \(kind.title)")

            NavigationLink(value: kind) {
                Image(systemName: "chevron.right")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(kind.title)")
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct AssessmentQuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: AssessmentKind
    @State private var currentQuestion = 0
    @State private var answers: [Int?]
    @State private var didSave = false
    @State private var saveErrorMessage: String?
    @State private var resultDate = Date()

    private var totalScore: Int {
        kind.score(from: answers)
    }

    private var totalScoreValue: Double {
        kind.scoreValue(from: answers)
    }

    private var isComplete: Bool {
        answers.allSatisfy { $0 != nil }
    }

    init(kind: AssessmentKind) {
        self.kind = kind
        _answers = State(initialValue: Array(repeating: nil, count: kind.questions.count))
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressView(value: Double(completedCount), total: Double(kind.questions.count))
                    .tint(themeManager.selectedColor)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                TabView(selection: $currentQuestion) {
                    ForEach(kind.questions.indices, id: \.self) { index in
                        AssessmentQuestionPage(
                            kind: kind,
                            questionIndex: index,
                            selectedAnswer: binding(for: index)
                        )
                        .tag(index)
                    }

                    AssessmentResultPage(
                        kind: kind,
                        answers: answers,
                        scoreValue: totalScoreValue,
                        completedAt: resultDate,
                        didSave: didSave,
                        saveErrorMessage: saveErrorMessage,
                        saveAction: saveAssessment
                    )
                    .tag(kind.questions.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.86), value: currentQuestion)

                AssessmentQuizControls(
                    currentQuestion: $currentQuestion,
                    questionCount: kind.questions.count,
                    canAdvance: currentQuestion < kind.questions.count && answers[currentQuestion] != nil,
                    isComplete: isComplete
                )
            }
        }
        .navigationTitle(kind.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            NotificationCenter.default.post(name: .quizFlowDidEnter, object: nil)
        }
        .onChange(of: currentQuestion) { _, newValue in
            if newValue == kind.questions.count {
                resultDate = Date()
            }
        }
        .onDisappear {
            NotificationCenter.default.post(name: .quizFlowDidExit, object: nil)
        }
    }

    private var completedCount: Int {
        answers.filter { $0 != nil }.count
    }

    private func binding(for index: Int) -> Binding<Int?> {
        Binding(
            get: { answers[index] },
            set: { newValue in
                answers[index] = newValue
            }
        )
    }

    private func saveAssessment() {
        guard !didSave else { return }
        let log = AssessmentLog(
            assessmentType: kind.rawValue,
            score: totalScore,
            scoreValue: totalScoreValue
        )
        modelContext.insert(log)

        do {
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)
            didSave = true
            saveErrorMessage = nil
            HapticManager.shared.success()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Could not save \(kind.title): \(error.localizedDescription)"
            HapticManager.shared.error()
        }
    }
}

private struct AssessmentQuestionPage: View {
    let kind: AssessmentKind
    let questionIndex: Int
    @Binding var selectedAnswer: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AssessmentDisclaimer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(kind.prompt)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(kind.questions[questionIndex].text)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(kind.answers) { answer in
                        AssessmentAnswerRow(
                            answer: answer,
                            isSelected: selectedAnswer == answer.id
                        ) {
                            HapticManager.shared.selection()
                            selectedAnswer = answer.id
                        }
                    }
                }
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }
}

private struct AssessmentAnswerRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let answer: AssessmentAnswer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? themeManager.selectedColor : Theme.tertiaryText.opacity(0.45), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(themeManager.selectedColor)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(answer.label)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text("\(answer.id)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
            }
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: isSelected, selectedColor: themeManager.selectedColor, size: .large))
        .accessibilityLabel("\(answer.id), \(answer.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AssessmentQuizControls: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var currentQuestion: Int
    let questionCount: Int
    let canAdvance: Bool
    let isComplete: Bool

    private var isResultPage: Bool {
        currentQuestion == questionCount
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.selection()
                withAnimation {
                    currentQuestion = max(0, currentQuestion - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(48), expands: false, tint: themeManager.selectedColor, hapticType: nil))
            .disabled(currentQuestion == 0)
            .accessibilityLabel("Previous")

            Text(isResultPage ? "Results" : "\(currentQuestion + 1) of \(questionCount)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)

            Button {
                HapticManager.shared.selection()
                withAnimation {
                    currentQuestion = min(questionCount, currentQuestion + 1)
                }
            } label: {
                Image(systemName: isResultPage ? "checkmark" : "chevron.right")
            }
            .buttonStyle(DSButtonStyle(variant: .primary, size: .icon(48), expands: false, tint: themeManager.selectedColor, hapticType: nil))
            .disabled(isResultPage || (!canAdvance && !isComplete))
            .accessibilityLabel(isResultPage ? "Complete" : "Next")
        }
        .padding(8)
        .background(Theme.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.isImmersive ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .cardShadow(colorScheme: colorScheme)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

private struct AssessmentResultPage: View {
    @Environment(ThemeManager.self) private var themeManager
    let kind: AssessmentKind
    let answers: [Int?]
    let scoreValue: Double
    let completedAt: Date
    let didSave: Bool
    let saveErrorMessage: String?
    let saveAction: () -> Void

    private var reportText: String {
        kind.exportText(answers: answers, completedAt: completedAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AssessmentDisclaimer()

                VStack(alignment: .leading, spacing: 12) {
                    Text(kind.resultTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            resultScoreText
                            resultInterpretationText
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            resultScoreText
                            resultInterpretationText
                        }
                    }

                    Text(kind.resultDescription(for: scoreValue))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let footnote = kind.resultFootnote {
                        Text(footnote)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(DSTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.paddingMedium)
                .cardStyle()

                AssessmentDocumentActions(
                    shareText: reportText,
                    printTitle: "\(kind.title) Result"
                )

                AssessmentNextStepsSection(steps: kind.recommendedNextSteps)

                Button {
                    saveAction()
                } label: {
                    Label(didSave ? "Saved to Trends" : "Save Result", systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
                }
                .buttonStyle(DSButtonStyle(variant: .primary, size: .large, tint: themeManager.selectedColor))
                .disabled(didSave)

                AssessmentSaveStatus(didSave: didSave, errorMessage: saveErrorMessage)

                AssessmentResultExplanationCard(
                    title: "What It Means",
                    systemImage: "lightbulb",
                    text: kind.resultExplanation(for: scoreValue)
                )

                AssessmentResultExplanationCard(
                    title: "How It Is Scored",
                    systemImage: "function",
                    text: kind.scoringExplanation
                )

                AssessmentAnswerBreakdownCard(kind: kind, answers: answers)
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }

    private var resultScoreText: some View {
        Text(kind.scoreText(for: scoreValue))
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
    }

    private var resultInterpretationText: some View {
        Text(kind.interpretation(for: scoreValue))
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AssessmentSaveStatus: View {
    let didSave: Bool
    let errorMessage: String?

    var body: some View {
        if didSave {
            Label("Saved locally. It will appear in Trends on the Assessments screen.", systemImage: "checkmark.circle.fill")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.successGreen)
                .fixedSize(horizontal: false, vertical: true)
        } else if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AssessmentResultExplanationCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .tint(themeManager.selectedColor)
    }
}

private struct AssessmentAnswerBreakdownCard: View {
    let kind: AssessmentKind
    let answers: [Int?]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answer Breakdown", systemImage: "list.bullet.rectangle")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(kind.questions.indices, id: \.self) { index in
                    AssessmentAnswerBreakdownRow(
                        questionNumber: index + 1,
                        question: kind.questions[index],
                        answerText: kind.answerText(for: answers[index]),
                        scoreText: kind.answerScoreText(question: kind.questions[index], answer: answers[index])
                    )

                    if index != kind.questions.indices.last {
                        Divider().opacity(0.45)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct AssessmentAnswerBreakdownRow: View {
    let questionNumber: Int
    let question: AssessmentQuestion
    let answerText: String
    let scoreText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(questionNumber). \(question.text)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(answerText)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(scoreText)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

struct AssessmentNextStepsSection: View {
    let steps: [AssessmentNextStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Next Steps")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            VStack(spacing: 10) {
                ForEach(steps) { step in
                    NavigationLink(destination: AssessmentNextStepDestinationView(step: step)) {
                        AssessmentNextStepRow(step: step)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AssessmentNextStepRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let step: AssessmentNextStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.leading)

                Text(step.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 10)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct AssessmentNextStepDestinationView: View {
    let step: AssessmentNextStep

    var body: some View {
        switch step.destination {
        case .exercise(let id):
            if let exercise = ExerciseService.shared.exercise(withID: id) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView("Exercise unavailable", systemImage: "exclamationmark.triangle")
            }
        case .activityPlanner:
            ActivityPlannerView()
        case .affirmations:
            AffirmationPlayerView()
        case .distortionExamples:
            DistortionExamplesView()
        case .guidedJournal:
            GuidedJournalPickerView()
        case .cbtGuide:
            WhatIsCBTPagerView()
        case .exercises:
            ExercisesView()
        }
    }
}

private struct AssessmentTrendsSection: View {
    let logs: [AssessmentLog]
    let personalityLogs: [PersonalityAssessmentLog]

    private var summaries: [AssessmentTrendSummary] {
        Dictionary(grouping: logs, by: \.assessmentType)
            .compactMap { assessmentType, groupedLogs in
                AssessmentTrendSummary(assessmentType: assessmentType, logs: groupedLogs)
            }
            .sorted { $0.latest.date > $1.latest.date }
    }

    private var recentItems: [AssessmentRecentResultItem] {
        let assessmentItems = logs.map(AssessmentRecentResultItem.init(log:))
        let personalityItems = personalityLogs.map(AssessmentRecentResultItem.init(log:))
        return (assessmentItems + personalityItems)
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            if logs.isEmpty && personalityLogs.isEmpty {
                VStack(spacing: 12) {
                    SupportiveEmptyStateView(
                        systemImage: "checklist",
                        title: "Assessment Trends",
                        message: "Assessments are brief self-checks for tracking anxiety, mood, stress, or mindful attention over time."
                    )
                    .padding(.horizontal, Theme.paddingMedium)

                    NavigationLink(value: AssessmentKind.gad7) {
                        Label("Start GAD-7", systemImage: AssessmentKind.gad7.symbolName)
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .frame(maxWidth: 320)
                    .padding(.horizontal, Theme.paddingMedium)
                    .padding(.bottom, Theme.paddingMedium)
                }
                .cardStyle()
            } else {
                if !summaries.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(summaries.prefix(6)) { summary in
                            AssessmentTrendSummaryRow(summary: summary)
                        }
                    }
                }

                Text("Recent Results")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryText)
                    .tracking(0.6)
                    .padding(.top, 6)

                ForEach(recentItems.prefix(8)) { item in
                    AssessmentLogRow(item: item)
                }
            }
        }
    }
}

private struct AssessmentTrendSummary: Identifiable {
    let assessmentType: String
    let logs: [AssessmentLog]

    var id: String { assessmentType }

    var kind: AssessmentKind? {
        AssessmentKind(rawValue: assessmentType)
    }

    var latest: AssessmentLog {
        sortedDescending[0]
    }

    var previous: AssessmentLog? {
        sortedDescending.dropFirst().first
    }

    var sortedDescending: [AssessmentLog] {
        logs.sorted { $0.date > $1.date }
    }

    var chronologicalValues: [Double] {
        sortedDescending
            .prefix(6)
            .reversed()
            .map(\.displayValue)
    }

    init?(assessmentType: String, logs: [AssessmentLog]) {
        guard !logs.isEmpty else { return nil }
        self.assessmentType = assessmentType
        self.logs = logs
    }
}

private struct AssessmentTrendSummaryRow: View {
    let summary: AssessmentTrendSummary

    private var latestValue: Double {
        summary.latest.displayValue
    }

    private var previousValue: Double? {
        summary.previous?.displayValue
    }

    private var scoreText: String {
        if let kind = summary.kind {
            return kind.scoreText(for: latestValue)
        }

        return "\(Int(latestValue.rounded()))"
    }

    private var interpretationText: String {
        summary.kind?.interpretation(for: latestValue) ?? "Saved Result"
    }

    private var change: Double? {
        guard let previousValue else { return nil }
        return latestValue - previousValue
    }

    private var changeText: String {
        guard let change else { return "First saved result" }
        guard abs(change) >= 0.05 else { return "Stable since last time" }

        let amount = summary.kind?.scoreText(for: abs(change)) ?? "\(Int(abs(change).rounded()))"
        if summary.kind?.isSupportiveScore == true {
            return change > 0 ? "Up \(amount) from last time" : "Down \(amount) from last time"
        }

        return change < 0 ? "Lower by \(amount) from last time" : "Higher by \(amount) from last time"
    }

    private var changeColor: Color {
        guard let change, abs(change) >= 0.05 else { return Theme.secondaryText }
        if summary.kind?.isSupportiveScore == true {
            return change > 0 ? Theme.successGreen : DSTheme.warning
        }

        return change < 0 ? Theme.successGreen : DSTheme.warning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.assessmentType)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(interpretationText)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(scoreText)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 12) {
                AssessmentMiniTrendBars(values: summary.chronologicalValues, kind: summary.kind)

                Text(changeText)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(changeColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct AssessmentMiniTrendBars: View {
    @Environment(ThemeManager.self) private var themeManager
    let values: [Double]
    let kind: AssessmentKind?

    private var scaleMaximum: Double {
        if let kind {
            return kind.scaleMaximum
        }

        return max(values.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(themeManager.selectedColor.opacity(0.75))
                    .frame(width: 7, height: max(5, min(28, 28 * value / scaleMaximum)))
            }
        }
        .frame(width: 62, height: 32, alignment: .bottomLeading)
        .accessibilityHidden(true)
    }
}

private struct AssessmentRecentResultItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let scoreText: String
    let symbolName: String

    init(log: AssessmentLog) {
        let kind = AssessmentKind(rawValue: log.assessmentType)
        let value = log.displayValue
        let interpretation = kind?.interpretation(for: value)
        let dateText = log.date.formatted(date: .abbreviated, time: .shortened)

        id = "assessment-\(log.id)"
        date = log.date
        title = log.assessmentType.isEmpty ? "Assessment" : log.assessmentType
        subtitle = [interpretation, dateText].compactMap { $0 }.joined(separator: " - ")
        scoreText = log.scoreText
        symbolName = kind?.symbolName ?? "chart.bar"
    }

    init(log: PersonalityAssessmentLog) {
        let definition = PersonalityAssessmentCatalog.definition
        let traitScores = [
            ("Openness", log.opennessScore),
            ("Conscientiousness", log.conscientiousnessScore),
            ("Extraversion", log.extraversionScore),
            ("Agreeableness", log.agreeablenessScore),
            ("Neuroticism", log.neuroticismScore)
        ]
        let averageScore = traitScores.map { $0.1 }.reduce(0, +) / Double(traitScores.count)
        let highestTrait = traitScores.max { $0.1 < $1.1 }?.0
        let dateText = log.date.formatted(date: .abbreviated, time: .shortened)

        id = "personality-\(log.id)"
        date = log.date
        title = definition.title
        subtitle = [highestTrait.map { "Highest: \($0)" }, dateText].compactMap { $0 }.joined(separator: " - ")
        scoreText = "Avg \(Int(averageScore.rounded()))%"
        symbolName = definition.symbolName
    }
}

private struct AssessmentLogRow: View {
    let item: AssessmentRecentResultItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 30, height: 30)
                .background(DSTheme.elevatedFill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(item.scoreText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private extension AssessmentLog {
    var displayValue: Double {
        scoreValue ?? Double(score)
    }

    var scoreText: String {
        if let kind = AssessmentKind(rawValue: assessmentType) {
            return kind.scoreText(for: displayValue)
        }

        return "\(score)"
    }
}

private struct AssessmentDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DSTheme.warning)
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 1)

            Text("This assessment is for informational and tracking purposes only. It is not a medical diagnosis or a substitute for professional clinical advice.")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.paddingMedium)
        .background(DSTheme.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DSTheme.warning.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct AssessmentInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    let kind: AssessmentKind

    var body: some View {
        NavigationStack {
            DSSheetContainer(maxContentWidth: 720) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Immersive Visual Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.selectedColor.opacity(0.12))
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .stroke(themeManager.selectedColor.opacity(0.3), lineWidth: 2)
                                    .frame(width: 90, height: 90)

                                Image(systemName: kind.symbolName)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                            .padding(.top, 10)

                            VStack(spacing: 6) {
                                Text(kind.title)
                                    .font(.system(.title2, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)

                                Text(kind.subtitle)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                        // 1. Overview Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(themeManager.selectedColor)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text("Overview")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                            }

                            Text(kind.whatItIs)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Theme.paddingMedium)
                        .cardStyle()

                        // 2. What it Tracks Section (with visual list items)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "checklist")
                                    .foregroundStyle(themeManager.selectedColor)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text("What It Tracks")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(kind.symptomsCovered) { item in
                                    HStack(spacing: 12) {
                                        Image(systemName: item.symbolName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(themeManager.selectedColor)
                                            .frame(width: 28, height: 28)
                                            .background(themeManager.selectedColor.opacity(0.08), in: Circle())

                                        Text(item.description)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Spacer()
                                    }
                                    .padding(.vertical, 2)

                                    if item.id != kind.symptomsCovered.last?.id {
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                        }
                        .padding(Theme.paddingMedium)
                        .cardStyle()

                        // 3. Visual Scoring Scale / Timeline
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(themeManager.selectedColor)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text("Scoring & Interpretation")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                            }

                            Text(kind.scoringRangeText)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 112), spacing: 10, alignment: .top)],
                                alignment: .leading,
                                spacing: 12
                            ) {
                                ForEach(kind.severityLevels) { level in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Capsule()
                                            .fill(level.color)
                                            .frame(height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(level.label)
                                                .font(.system(size: 11, design: .rounded).weight(.bold))
                                                .foregroundStyle(Theme.primaryText)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.78)
                                                .fixedSize(horizontal: false, vertical: true)

                                            Text(level.rangeText)
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(Theme.secondaryText)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(Theme.paddingMedium)
                        .cardStyle()

                        // 4. Why Track This Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundStyle(themeManager.selectedColor)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                Text("Why Track This?")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)
                            }

                            Text(kind.whyItMatters)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Theme.paddingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                                .fill(themeManager.selectedColor.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                                .strokeBorder(themeManager.selectedColor.opacity(0.15), lineWidth: 1)
                        )
                        .overlay(
                            Rectangle()
                                .fill(themeManager.selectedColor)
                                .frame(width: 4),
                            alignment: .leading
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
                    }
                    .padding(.vertical, DSSpacing.small)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Assessment Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
        }
        .dsSheetPresentation(detents: [.medium, .large])
    }
}
