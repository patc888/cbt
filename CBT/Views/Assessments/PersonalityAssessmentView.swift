import SwiftData
import SwiftUI

struct PersonalityAssessmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasStarted = false
    @State private var hasCompletedGroundingPreparation = false
    @State private var currentQuestion = 0
    @State private var answers: [Int?] = Array(repeating: nil, count: PersonalityAssessmentEngine.questions.count)
    @State private var didSave = false
    @State private var saveErrorMessage: String?
    @State private var resultDate = Date()
    @State private var showingReset = false

    private var completedCount: Int {
        answers.filter { $0 != nil }.count
    }

    private var isComplete: Bool {
        answers.allSatisfy { $0 != nil }
    }

    private var canAdvanceFromCurrentQuestion: Bool {
        guard currentQuestion < PersonalityAssessmentEngine.questions.count,
              answers.indices.contains(currentQuestion)
        else {
            return false
        }

        return answers[currentQuestion] != nil
    }

    private var results: PersonalityResults? {
        PersonalityAssessmentEngine.results(from: answers)
    }

    private var definition: PersonalityAssessmentDefinition {
        PersonalityAssessmentCatalog.definition
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            if hasStarted && !hasCompletedGroundingPreparation {
                groundingPreparation
            } else if hasStarted {
                wizardContent
            } else {
                introContent
            }
        }
        .navigationTitle(definition.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            NotificationCenter.default.post(name: .quizFlowDidEnter, object: nil)
        }
        .onChange(of: currentQuestion) { _, newValue in
            if newValue == PersonalityAssessmentEngine.questions.count {
                resultDate = Date()
            }
        }
        .onDisappear {
            NotificationCenter.default.post(name: .quizFlowDidExit, object: nil)
        }
        .sheet(isPresented: $showingReset) {
            NavigationStack {
                BreathingResetView(
                    durationSeconds: 60,
                    pattern: .box,
                    autoStart: true,
                    showsDismissControl: true,
                    showControls: true,
                    hideBackground: false,
                    onComplete: nil,
                    onDismiss: { showingReset = false }
                )
            }
            .dsSheetPresentation()
        }
    }

    private var introContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppScreenHeadline(title: definition.title)

                PersonalityDisclaimer()

                VStack(alignment: .leading, spacing: 12) {
                    Label("\(definition.questions.count) prompts", systemImage: "list.number")
                    Label("\(definition.answerScale.answers.count)-point agreement scale", systemImage: "slider.horizontal.3")
                    Label("Private, local trend tracking", systemImage: "lock")
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding(Theme.paddingMedium)
                .cardStyle()

                Text(definition.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticManager.shared.mediumImpact()
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.86)) {
                        hasStarted = true
                    }
                } label: {
                    Label("Begin", systemImage: "arrow.right")
                }
                .buttonStyle(DSButtonStyle(variant: .primary, tint: themeManager.selectedColor, hapticType: nil))
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }

    private var wizardContent: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(completedCount), total: Double(PersonalityAssessmentEngine.questions.count))
                .tint(themeManager.selectedColor)
                .padding(.horizontal, 18)
                .padding(.top, 10)

            TabView(selection: $currentQuestion) {
                ForEach(PersonalityAssessmentEngine.questions.indices, id: \.self) { index in
                    PersonalityQuestionPage(
                        question: PersonalityAssessmentEngine.questions[index],
                        answerScale: definition.answerScale,
                        questionNumber: index + 1,
                        questionCount: PersonalityAssessmentEngine.questions.count,
                        selectedAnswer: binding(for: index)
                    )
                    .tag(index)
                }

                PersonalityResultsPage(
                    results: results,
                    completedAt: resultDate,
                    didSave: didSave,
                    saveErrorMessage: saveErrorMessage,
                    saveAction: saveResults
                )
                .tag(PersonalityAssessmentEngine.questions.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.86), value: currentQuestion)

            PersonalityWizardControls(
                currentQuestion: $currentQuestion,
                questionCount: PersonalityAssessmentEngine.questions.count,
                canAdvance: canAdvanceFromCurrentQuestion,
                isComplete: isComplete
            )

            if currentQuestion < PersonalityAssessmentEngine.questions.count {
                PersonalityNotReadyActions(
                    comeBackLater: { dismiss() },
                    resetInstead: { showingReset = true }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var groundingPreparation: some View {
        VStack {
            GroundingPreparationView(
                title: String(localized: "Ground Before the Assessment"),
                message: String(localized: "This self-discovery assessment asks you to reflect on patterns that may feel personal. You can take a 30-second breathing reset first, or begin when you feel ready."),
                continueTitle: String(localized: "Start Assessment")
            ) {
                hasCompletedGroundingPreparation = true
            }
            .padding(.horizontal, DSSpacing.large)
            .responsiveMaxWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for index: Int) -> Binding<Int?> {
        Binding(
            get: {
                guard answers.indices.contains(index) else { return nil }
                return answers[index]
            },
            set: {
                guard answers.indices.contains(index) else { return }
                answers[index] = $0
            }
        )
    }

    private func saveResults() {
        guard !didSave, let results else { return }
        let log = PersonalityAssessmentLog(
            opennessScore: results.opennessScore,
            conscientiousnessScore: results.conscientiousnessScore,
            extraversionScore: results.extraversionScore,
            agreeablenessScore: results.agreeablenessScore,
            neuroticismScore: results.neuroticismScore
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
            saveErrorMessage = "Could not save \(definition.title): \(error.localizedDescription)"
            HapticManager.shared.error()
        }
    }
}

private struct PersonalityQuestionPage: View {
    let question: PersonalityQuestion
    let answerScale: PersonalityAnswerScale
    let questionNumber: Int
    let questionCount: Int
    @Binding var selectedAnswer: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PersonalityDisclaimer()

                VStack(alignment: .leading, spacing: 8) {
                    Label(question.trait.rawValue, systemImage: question.trait.symbolName)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)

                    Text(question.text)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(answerScale.minimumLabel)
                        Spacer()
                        Text(answerScale.maximumLabel)
                    }
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(answerScale.answers, id: \.self) { value in
                            PersonalityChoiceButton(
                                value: value,
                                isSelected: selectedAnswer == value
                            ) {
                                HapticManager.shared.selection()
                                selectedAnswer = value
                            }
                        }
                    }
                }
                .padding(Theme.paddingMedium)
                .cardStyle()

                Text("\(questionNumber) of \(questionCount)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }
}

private struct PersonalityChoiceButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let value: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: isSelected, selectedColor: themeManager.selectedColor, size: .icon(52), expands: false))
        .accessibilityLabel("\(value)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PersonalityNotReadyActions: View {
    @Environment(ThemeManager.self) private var themeManager
    let comeBackLater: () -> Void
    let resetInstead: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                actions
            }

            VStack(spacing: 10) {
                actions
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button {
            resetInstead()
        } label: {
            Label("Do a 60-second reset instead", systemImage: "wind")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))

        Button {
            comeBackLater()
        } label: {
            Label("Come back later", systemImage: "clock")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, expands: true, tint: themeManager.selectedColor))
    }
}

private struct PersonalityWizardControls: View {
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

            Text(isResultPage ? PersonalityAssessmentCatalog.definition.resultTitle : "\(currentQuestion + 1) of \(questionCount)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)

            Button {
                HapticManager.shared.selection()
                withAnimation {
                    currentQuestion = min(questionCount, currentQuestion + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(DSButtonStyle(variant: .primary, size: .icon(48), expands: false, tint: themeManager.selectedColor, hapticType: nil))
            .disabled(isResultPage || (!canAdvance && !isComplete))
            .accessibilityLabel("Next")
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

private struct PersonalityResultsPage: View {
    @Environment(ThemeManager.self) private var themeManager
    let results: PersonalityResults?
    let completedAt: Date
    let didSave: Bool
    let saveErrorMessage: String?
    let saveAction: () -> Void

    private var reportText: String {
        PersonalityAssessmentReport.exportText(results: results, completedAt: completedAt)
    }

    private var definition: PersonalityAssessmentDefinition {
        PersonalityAssessmentCatalog.definition
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PersonalityDisclaimer()

                VStack(alignment: .leading, spacing: 14) {
                    Text(definition.resultTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    if let results {
                        ForEach(PersonalityTrait.allCases) { trait in
                            PersonalityTraitResultRow(
                                trait: trait,
                                score: results.score(for: trait)
                            )
                        }
                    }
                }
                .padding(Theme.paddingMedium)
                .cardStyle()

                AssessmentDocumentActions(
                    shareText: reportText,
                    printTitle: "\(definition.title) Result"
                )

                AssessmentNextStepsSection(steps: definition.recommendedNextSteps)

                Button {
                    saveAction()
                } label: {
                    Label(didSave ? definition.savedButtonTitle : definition.saveButtonTitle, systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
                }
                .buttonStyle(DSButtonStyle(variant: .primary, size: .large, tint: themeManager.selectedColor))
                .disabled(didSave || results == nil)

                PersonalitySaveStatus(didSave: didSave, errorMessage: saveErrorMessage)

                PersonalityExplanationCard(
                    title: "How To Read This",
                    systemImage: "lightbulb",
                    text: definition.interpretation
                )

                if let results {
                    PersonalityExplanationCard(
                        title: "Pattern Summary",
                        systemImage: "chart.bar.xaxis",
                        text: results.patternSummary
                    )
                }
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }
}

private struct PersonalitySaveStatus: View {
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

private struct PersonalityExplanationCard: View {
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

private struct PersonalityTraitResultRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let trait: PersonalityTrait
    let score: Double

    private var normalizedScore: Double {
        min(1, max(0, score / 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: trait.symbolName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 28, height: 28)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                Text(trait.rawValue)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text("\(Int(score.rounded()))%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
            }

            ProgressView(value: normalizedScore)
                .tint(themeManager.selectedColor)

            Text("\(trait.bandLabel(for: score)) range. \(trait.explanation(for: score))")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

private enum PersonalityAssessmentReport {
    static func exportText(results: PersonalityResults?, completedAt: Date) -> String {
        let definition = PersonalityAssessmentCatalog.definition
        guard let results else {
            return """
            \(definition.title) Result
            Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))

            The assessment is not complete yet.
            """
        }

        let traitLines = PersonalityTrait.allCases
            .map { trait in
                let score = results.score(for: trait)
                return "- \(trait.rawValue): \(Int(score.rounded()))% (\(trait.bandLabel(for: score)))\n  \(trait.explanation(for: score))"
            }
            .joined(separator: "\n")

        return """
        \(definition.title) Result
        Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))

        Average trait score: \(Int(results.averageScore.rounded()))%

        Pattern summary:
        \(results.patternSummary)

        Trait scores:
        \(traitLines)

        How to read this:
        \(definition.interpretation)

        Note:
        \(definition.disclaimer)
        """
    }
}

private struct PersonalityDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DSTheme.warning)
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 1)

            Text(PersonalityAssessmentCatalog.definition.disclaimer)
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
