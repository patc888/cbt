import SwiftData
import SwiftUI

private enum PersonalityTrait: String, CaseIterable, Identifiable {
    case openness = "Openness"
    case conscientiousness = "Conscientiousness"
    case extraversion = "Extraversion"
    case agreeableness = "Agreeableness"
    case neuroticism = "Neuroticism"

    var id: String { rawValue }

    var definition: PersonalityTraitDefinition {
        PersonalityAssessmentDefinitionStore.definition.traitDefinition(for: self)
    }

    var symbolName: String { definition.symbolName }

    func bandLabel(for score: Double) -> String {
        definition.band(for: score).label
    }

    func explanation(for score: Double) -> String {
        definition.band(for: score).interpretation
    }
}

private struct PersonalityTraitDefinition: Identifiable {
    var id: String { trait.rawValue }

    let trait: PersonalityTrait
    let symbolName: String
    let bands: [PersonalityScoreBand]

    func band(for score: Double) -> PersonalityScoreBand {
        bands.first { $0.contains(score) } ?? bands[bands.count / 2]
    }
}

private struct PersonalityScoreBand: Identifiable {
    var id: String { "\(label)-\(range.lowerBound)-\(range.upperBound)" }

    let label: String
    let range: ClosedRange<Double>
    let interpretation: String

    func contains(_ score: Double) -> Bool {
        score >= range.lowerBound && score <= range.upperBound
    }
}

private struct PersonalityAnswerScale {
    let minimumValue: Int
    let maximumValue: Int
    let minimumLabel: String
    let maximumLabel: String
    let answers: [Int]
}

private struct PersonalityNextStep: Identifiable {
    enum Destination {
        case guidedJournal
        case activityPlanner
        case exercises
    }

    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let destination: Destination
}

private struct PersonalityAssessmentDefinition {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let disclaimer: String
    let questions: [PersonalityQuestion]
    let answerScale: PersonalityAnswerScale
    let traits: [PersonalityTraitDefinition]
    let resultTitle: String
    let interpretation: String
    let saveButtonTitle: String
    let savedButtonTitle: String
    let recommendedNextSteps: [PersonalityNextStep]

    func traitDefinition(for trait: PersonalityTrait) -> PersonalityTraitDefinition {
        guard let definition = traits.first(where: { $0.trait == trait }) else {
            preconditionFailure("Missing personality trait definition for \(trait.rawValue)")
        }

        return definition
    }
}

private struct PersonalityQuestion: Identifiable {
    let id: Int
    let trait: PersonalityTrait
    let text: String
    let isReverseScored: Bool

    func scoredValue(for answer: Int, answerScale: PersonalityAnswerScale) -> Int {
        isReverseScored ? answerScale.minimumValue + answerScale.maximumValue - answer : answer
    }
}

private struct PersonalityResults: Equatable {
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

private enum PersonalityAssessmentDefinitionStore {
    static let definition = PersonalityAssessmentDefinition(
        id: "big-five",
        title: "Big Five",
        subtitle: "OCEAN self-discovery snapshot",
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
            PersonalityNextStep(id: "guided-journal", title: "Guided Journal", subtitle: "Turn the snapshot into a short reflection.", symbolName: "pencil.and.list.clipboard", destination: .guidedJournal),
            PersonalityNextStep(id: "activity-planner", title: "Activity Planner", subtitle: "Plan a task that fits your energy and style.", symbolName: "calendar.badge.clock", destination: .activityPlanner),
            PersonalityNextStep(id: "exercises", title: "Exercises", subtitle: "Browse coping tools that match what you noticed.", symbolName: "figure.mind.and.body", destination: .exercises)
        ]
    )
}

private enum PersonalityAssessmentEngine {
    static var questions: [PersonalityQuestion] {
        PersonalityAssessmentDefinitionStore.definition.questions
    }

    static func results(from answers: [Int?]) -> PersonalityResults? {
        let definition = PersonalityAssessmentDefinitionStore.definition
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

struct PersonalityAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasStarted = false
    @State private var currentQuestion = 0
    @State private var answers: [Int?] = Array(repeating: nil, count: PersonalityAssessmentEngine.questions.count)
    @State private var didSave = false
    @State private var saveErrorMessage: String?
    @State private var resultDate = Date()

    private var completedCount: Int {
        answers.filter { $0 != nil }.count
    }

    private var isComplete: Bool {
        answers.allSatisfy { $0 != nil }
    }

    private var results: PersonalityResults? {
        PersonalityAssessmentEngine.results(from: answers)
    }

    private var definition: PersonalityAssessmentDefinition {
        PersonalityAssessmentDefinitionStore.definition
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            if hasStarted {
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
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.selectedColor, in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
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
                canAdvance: currentQuestion < PersonalityAssessmentEngine.questions.count && answers[currentQuestion] != nil,
                isComplete: isComplete
            )
        }
    }

    private func binding(for index: Int) -> Binding<Int?> {
        Binding(
            get: { answers[index] },
            set: { answers[index] = $0 }
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
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(isSelected ? .white : Theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isSelected ? themeManager.selectedColor : DSTheme.elevatedFill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(isSelected ? themeManager.selectedColor.opacity(0.6) : DSTheme.separator.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(currentQuestion == 0 ? Theme.tertiaryText : themeManager.selectedColor)
                    .frame(width: 48, height: 48)
                    .background(currentQuestion == 0 ? Color.clear : DSTheme.elevatedFill, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentQuestion == 0)
            .accessibilityLabel("Previous")

            Text(isResultPage ? "Trait Overview" : "\(currentQuestion + 1) of \(questionCount)")
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle((canAdvance || isComplete) ? .white : Theme.tertiaryText)
                    .frame(width: 48, height: 48)
                    .background((canAdvance || isComplete) ? themeManager.selectedColor : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
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
        PersonalityAssessmentDefinitionStore.definition
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

                PersonalityNextStepsSection(steps: definition.recommendedNextSteps)

                Button {
                    saveAction()
                } label: {
                    Label(didSave ? definition.savedButtonTitle : definition.saveButtonTitle, systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.selectedColor, in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
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

private struct PersonalityNextStepsSection: View {
    let steps: [PersonalityNextStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Next Steps")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            VStack(spacing: 10) {
                ForEach(steps) { step in
                    NavigationLink(destination: PersonalityNextStepDestinationView(step: step)) {
                        PersonalityNextStepRow(step: step)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PersonalityNextStepRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let step: PersonalityNextStep

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

private struct PersonalityNextStepDestinationView: View {
    let step: PersonalityNextStep

    var body: some View {
        switch step.destination {
        case .guidedJournal:
            GuidedJournalPickerView()
        case .activityPlanner:
            ActivityPlannerView()
        case .exercises:
            ExercisesView()
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
        let definition = PersonalityAssessmentDefinitionStore.definition
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

            Text(PersonalityAssessmentDefinitionStore.definition.disclaimer)
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
