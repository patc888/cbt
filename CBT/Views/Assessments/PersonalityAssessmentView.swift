import SwiftData
import SwiftUI

private enum PersonalityTrait: String, CaseIterable, Identifiable {
    case openness = "Openness"
    case conscientiousness = "Conscientiousness"
    case extraversion = "Extraversion"
    case agreeableness = "Agreeableness"
    case neuroticism = "Neuroticism"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .openness:
            return "sparkles"
        case .conscientiousness:
            return "checkmark.seal"
        case .extraversion:
            return "person.2"
        case .agreeableness:
            return "heart"
        case .neuroticism:
            return "waveform.path.ecg"
        }
    }

    var highDescription: String {
        switch self {
        case .openness:
            return "Higher scores often reflect imagination, curiosity, and comfort with novelty."
        case .conscientiousness:
            return "Higher scores often reflect organization, follow-through, and careful effort."
        case .extraversion:
            return "Higher scores often reflect social energy, assertiveness, and stimulation seeking."
        case .agreeableness:
            return "Higher scores often reflect trust, cooperation, and warmth toward others."
        case .neuroticism:
            return "Higher scores often reflect more emotional sensitivity and stress reactivity."
        }
    }

    var lowDescription: String {
        switch self {
        case .openness:
            return "Lower scores can reflect preference for familiarity, practicality, and concrete routines."
        case .conscientiousness:
            return "Lower scores can reflect flexibility, spontaneity, and less emphasis on structure."
        case .extraversion:
            return "Lower scores can reflect reserved energy, quiet focus, and comfort with solitude."
        case .agreeableness:
            return "Lower scores can reflect directness, skepticism, and stronger personal boundaries."
        case .neuroticism:
            return "Lower scores can reflect steadiness, stress tolerance, and emotional calm."
        }
    }
}

private struct PersonalityQuestion: Identifiable {
    let id: Int
    let trait: PersonalityTrait
    let text: String
    let isReverseScored: Bool

    func scoredValue(for answer: Int) -> Int {
        isReverseScored ? 6 - answer : answer
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
}

private enum PersonalityAssessmentEngine {
    static let questions: [PersonalityQuestion] = [
        PersonalityQuestion(
            id: 0,
            trait: .extraversion,
            text: "I am someone who is outgoing, sociable.",
            isReverseScored: false
        ),
        PersonalityQuestion(
            id: 1,
            trait: .extraversion,
            text: "I am someone who is reserved, quiet.",
            isReverseScored: true
        ),
        PersonalityQuestion(
            id: 2,
            trait: .agreeableness,
            text: "I am someone who is generally trusting.",
            isReverseScored: false
        ),
        PersonalityQuestion(
            id: 3,
            trait: .agreeableness,
            text: "I am someone who tends to find fault with others.",
            isReverseScored: true
        ),
        PersonalityQuestion(
            id: 4,
            trait: .conscientiousness,
            text: "I am someone who does a thorough job.",
            isReverseScored: false
        ),
        PersonalityQuestion(
            id: 5,
            trait: .conscientiousness,
            text: "I am someone who tends to be lazy or easily distracted.",
            isReverseScored: true
        ),
        PersonalityQuestion(
            id: 6,
            trait: .neuroticism,
            text: "I am someone who is relaxed, handles stress well.",
            isReverseScored: true
        ),
        PersonalityQuestion(
            id: 7,
            trait: .neuroticism,
            text: "I am someone who gets nervous easily.",
            isReverseScored: false
        ),
        PersonalityQuestion(
            id: 8,
            trait: .openness,
            text: "I am someone who has an active imagination.",
            isReverseScored: false
        ),
        PersonalityQuestion(
            id: 9,
            trait: .openness,
            text: "I am someone who has relatively few artistic interests.",
            isReverseScored: true
        )
    ]

    static func results(from answers: [Int?]) -> PersonalityResults? {
        guard answers.count == questions.count, answers.allSatisfy({ $0 != nil }) else {
            return nil
        }

        var rawScores: [PersonalityTrait: Int] = [:]

        for question in questions {
            guard let answer = answers[question.id] else { return nil }
            rawScores[question.trait, default: 0] += question.scoredValue(for: answer)
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

    private var completedCount: Int {
        answers.filter { $0 != nil }.count
    }

    private var isComplete: Bool {
        answers.allSatisfy { $0 != nil }
    }

    private var results: PersonalityResults? {
        PersonalityAssessmentEngine.results(from: answers)
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
        .navigationTitle("Big Five")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var introContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppScreenHeadline(title: "Big Five")

                PersonalityDisclaimer()

                VStack(alignment: .leading, spacing: 12) {
                    Label("10 prompts", systemImage: "list.number")
                    Label("5-point agreement scale", systemImage: "slider.horizontal.3")
                    Label("Private, local trend tracking", systemImage: "lock")
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding(Theme.paddingMedium)
                .cardStyle()

                Text("A compact OCEAN snapshot for self-reflection: Openness, Conscientiousness, Extraversion, Agreeableness, and Neuroticism.")
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
                        questionNumber: index + 1,
                        questionCount: PersonalityAssessmentEngine.questions.count,
                        selectedAnswer: binding(for: index)
                    )
                    .tag(index)
                }

                PersonalityResultsPage(
                    results: results,
                    didSave: didSave,
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
        modelContext.insert(
            PersonalityAssessmentLog(
                opennessScore: results.opennessScore,
                conscientiousnessScore: results.conscientiousnessScore,
                extraversionScore: results.extraversionScore,
                agreeablenessScore: results.agreeablenessScore,
                neuroticismScore: results.neuroticismScore
            )
        )
        try? modelContext.save()
        didSave = true
    }
}

private struct PersonalityQuestionPage: View {
    let question: PersonalityQuestion
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
                        Text("Disagree strongly")
                        Spacer()
                        Text("Agree strongly")
                    }
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { value in
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
    let didSave: Bool
    let saveAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PersonalityDisclaimer()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Trait Overview")
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

                Button {
                    HapticManager.shared.success()
                    saveAction()
                } label: {
                    Label(didSave ? "Saved" : "Save Reflection", systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.selectedColor, in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(didSave || results == nil)
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
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

            Text(score >= 50 ? trait.highDescription : trait.lowDescription)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

private struct PersonalityDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DSTheme.warning)
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 1)

            Text("This assessment is for self-discovery and entertainment purposes only. It is not a psychological or clinical evaluation.")
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
