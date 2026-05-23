import SwiftData
import SwiftUI

private enum AssessmentKind: String, CaseIterable, Identifiable {
    case gad7 = "GAD-7"
    case phq8 = "PHQ-8"
    case pss4 = "PSS-4"
    case maas5 = "MAAS-5"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .gad7:
            return "Anxiety symptom tracking"
        case .phq8:
            return "Depression symptom tracking"
        case .pss4:
            return "Lifestyle stress tracking"
        case .maas5:
            return "Mindful attention tracking"
        }
    }

    var symbolName: String {
        switch self {
        case .gad7:
            return "wind"
        case .phq8:
            return "heart.text.square"
        case .pss4:
            return "gauge.with.dots.needle.67percent"
        case .maas5:
            return "leaf"
        }
    }

    var prompt: String {
        switch self {
        case .gad7, .phq8:
            return "Over the last 2 weeks, how often have you been bothered by the following?"
        case .pss4:
            return "In the past month..."
        case .maas5:
            return "How frequently do you experience each of the following?"
        }
    }

    var questions: [AssessmentQuestion] {
        switch self {
        case .gad7:
            return [
                AssessmentQuestion(text: "Feeling nervous, anxious or on edge"),
                AssessmentQuestion(text: "Not being able to stop or control worrying"),
                AssessmentQuestion(text: "Worrying too much about different things"),
                AssessmentQuestion(text: "Trouble relaxing"),
                AssessmentQuestion(text: "Being so restless that it is hard to sit still"),
                AssessmentQuestion(text: "Becoming easily annoyed or irritable"),
                AssessmentQuestion(text: "Feeling afraid as if something awful might happen")
            ]
        case .phq8:
            return [
                AssessmentQuestion(text: "Little interest or pleasure in doing things"),
                AssessmentQuestion(text: "Feeling down, depressed, or hopeless"),
                AssessmentQuestion(text: "Trouble falling or staying asleep, or sleeping too much"),
                AssessmentQuestion(text: "Feeling tired or having little energy"),
                AssessmentQuestion(text: "Poor appetite or overeating"),
                AssessmentQuestion(text: "Feeling bad about yourself – or that you are a failure"),
                AssessmentQuestion(text: "Trouble concentrating on things"),
                AssessmentQuestion(text: "Moving or speaking so slowly, or being excessively fidgety/restless")
            ]
        case .pss4:
            return [
                AssessmentQuestion(text: "How often have you felt that you were unable to control the important things in your life?"),
                AssessmentQuestion(text: "How often have you felt confident about your ability to handle your personal problems?", isReverseScored: true),
                AssessmentQuestion(text: "How often have you felt that things were going your way?", isReverseScored: true),
                AssessmentQuestion(text: "How often have you felt difficulties were piling up so high that you could not overcome them?")
            ]
        case .maas5:
            return [
                AssessmentQuestion(text: "I could be experiencing some emotion and not be conscious of it until some time later."),
                AssessmentQuestion(text: "I break or spill things because of carelessness, not paying attention, or thinking of something else."),
                AssessmentQuestion(text: "I find it difficult to stay focused on what’s happening in the present."),
                AssessmentQuestion(text: "I do jobs or tasks automatically, without being aware of what I'm doing."),
                AssessmentQuestion(text: "I rush through activities without being really attentive to them.")
            ]
        }
    }

    var answers: [AssessmentAnswer] {
        switch self {
        case .gad7, .phq8:
            return [
                AssessmentAnswer(id: 0, label: "Not at all"),
                AssessmentAnswer(id: 1, label: "Several days"),
                AssessmentAnswer(id: 2, label: "More than half the days"),
                AssessmentAnswer(id: 3, label: "Nearly every day")
            ]
        case .pss4:
            return [
                AssessmentAnswer(id: 0, label: "Never"),
                AssessmentAnswer(id: 1, label: "Almost Never"),
                AssessmentAnswer(id: 2, label: "Sometimes"),
                AssessmentAnswer(id: 3, label: "Fairly Often"),
                AssessmentAnswer(id: 4, label: "Very Often")
            ]
        case .maas5:
            return [
                AssessmentAnswer(id: 1, label: "Almost Always"),
                AssessmentAnswer(id: 2, label: "Very Frequently"),
                AssessmentAnswer(id: 3, label: "Somewhat Frequently"),
                AssessmentAnswer(id: 4, label: "Somewhat Infrequently"),
                AssessmentAnswer(id: 5, label: "Very Infrequently"),
                AssessmentAnswer(id: 6, label: "Almost Never")
            ]
        }
    }

    var resultTitle: String {
        switch self {
        case .gad7, .phq8:
            return "Symptom Severity Risk"
        case .pss4:
            return "Stress Load"
        case .maas5:
            return "Mindful Awareness"
        }
    }

    var resultDescription: String {
        switch self {
        case .gad7, .phq8:
            return "This label reflects symptom severity risk for tracking. It is not a medical diagnosis."
        case .pss4:
            return "This label reflects perceived stress for self-tracking. It is not a medical diagnosis."
        case .maas5:
            return "This label reflects day-to-day mindful attention for self-tracking. It is not a psychological or clinical evaluation."
        }
    }

    var detailedDescription: String {
        switch self {
        case .gad7:
            return "The Generalized Anxiety Disorder 7-item (GAD-7) is a widely used clinical screening tool for measuring the severity of generalized anxiety disorder (GAD). It helps track anxiety symptoms such as excessive worrying, restlessness, and feeling on edge. It can be a helpful tool in identifying how anxiety fluctuates over time and assessing if management strategies are effective."
        case .phq8:
            return "The Patient Health Questionnaire 8-item (PHQ-8) is a standardized, clinically validated tool used to monitor and measure the severity of depression symptoms. It assesses various domains such as mood, energy levels, sleep patterns, and concentration. Tracking these symptoms can provide valuable insights into your overall emotional well-being and the effectiveness of your coping strategies."
        case .pss4:
            return "The Perceived Stress Scale 4-item (PSS-4) is a brief psychological instrument for measuring the degree to which situations in your life are appraised as stressful. It evaluates how unpredictable, uncontrollable, and overloaded you find your life right now. It's excellent for understanding your subjective stress load and identifying periods where you might need more self-care."
        case .maas5:
            return "The Mindful Attention Awareness Scale 5-item (MAAS-5) measures your core characteristic of mindfulness—specifically, your open and receptive awareness of and attention to what is taking place in the present. This assessment helps you understand how often you act on 'autopilot' versus being fully engaged in your current experience."
        }
    }

    func score(from answers: [Int?]) -> Int {
        if self == .maas5 {
            return Int(scoreValue(from: answers).rounded())
        }

        return questions.indices.reduce(0) { total, index in
            guard let answer = answers[index] else { return total }
            return total + questions[index].scoredValue(for: answer, maximumAnswer: self.answers.last?.id ?? 0)
        }
    }

    func scoreValue(from answers: [Int?]) -> Double {
        if self == .maas5 {
            let completedAnswers = answers.compactMap { $0 }
            guard completedAnswers.count == questions.count else { return 0 }
            return Double(completedAnswers.reduce(0, +)) / Double(questions.count)
        }

        return Double(score(from: answers))
    }

    func scoreText(for value: Double) -> String {
        switch self {
        case .maas5:
            return String(format: "%.1f", value)
        case .gad7, .phq8, .pss4:
            return "\(Int(value.rounded()))"
        }
    }

    func interpretation(for value: Double) -> String {
        if self == .maas5 {
            switch value {
            case 1.0..<3.0:
                return "Low Mindfulness/High Distraction"
            case 3.0...4.5:
                return "Moderate Mindfulness"
            case 4.6...6.0:
                return "High Mindful Awareness"
            default:
                return "Mindfulness"
            }
        }

        let score = Int(value.rounded())
        switch score {
        case 0...5 where self == .pss4:
            return "Low Stress"
        case 6...10 where self == .pss4:
            return "Moderate Stress"
        case 11...16 where self == .pss4:
            return "High Stress"
        case 0...4:
            return "Minimal"
        case 5...9:
            return "Mild"
        case 10...14:
            return "Moderate"
        default:
            switch self {
            case .gad7:
                return "Severe Anxiety Risk"
            case .phq8:
                return "Severe Depression Risk"
            case .pss4:
                return "High Stress"
            case .maas5:
                return "Mindfulness"
            }
        }
    }
}

private struct AssessmentQuestion {
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

private struct AssessmentAnswer: Identifiable {
    let id: Int
    let label: String
}

struct AssessmentsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \AssessmentLog.date, order: .reverse) private var logs: [AssessmentLog]
    @State private var infoKind: AssessmentKind?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppScreenHeadline(title: "Assessments")

                        AssessmentDisclaimer()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)

                            ForEach(AssessmentKind.allCases) { kind in
                                NavigationLink(value: kind) {
                                    AssessmentStartRow(kind: kind) {
                                        infoKind = kind
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            NavigationLink {
                                PersonalityAssessmentView()
                            } label: {
                                SelfDiscoveryStartRow()
                            }
                            .buttonStyle(.plain)
                        }

                        AssessmentTrendsSection(logs: logs)
                    }
                    .dsContentLayout()
                    .padding(.vertical, 18)
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

private struct SelfDiscoveryStartRow: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 42, height: 42)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Big Five")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Text("OCEAN self-discovery snapshot")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

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
            Image(systemName: kind.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 42, height: 42)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Text(kind.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Image(systemName: "info.circle")
                .font(.system(size: 22))
                .foregroundStyle(themeManager.selectedColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    infoAction()
                }

            Image(systemName: "chevron.right")
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
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
                        scoreValue: totalScoreValue,
                        didSave: didSave,
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
        modelContext.insert(
            AssessmentLog(
                assessmentType: kind.rawValue,
                score: totalScore,
                scoreValue: totalScoreValue
            )
        )
        try? modelContext.save()
        didSave = true
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
            .padding(14)
            .background(isSelected ? themeManager.selectedColor.opacity(0.12) : DSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? themeManager.selectedColor.opacity(0.5) : DSTheme.separator.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(currentQuestion == 0 ? Theme.tertiaryText : themeManager.selectedColor)
                    .frame(width: 48, height: 48)
                    .background(currentQuestion == 0 ? Color.clear : DSTheme.elevatedFill, in: Circle())
            }
            .buttonStyle(.plain)
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle((canAdvance || isComplete) ? .white : Theme.tertiaryText)
                    .frame(width: 48, height: 48)
                    .background((canAdvance || isComplete) ? themeManager.selectedColor : Color.clear, in: Circle())
            }
            .buttonStyle(.plain)
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
    let scoreValue: Double
    let didSave: Bool
    let saveAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AssessmentDisclaimer()

                VStack(alignment: .leading, spacing: 12) {
                    Text(kind.resultTitle)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(kind.scoreText(for: scoreValue))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.selectedColor)
                        Text(kind.interpretation(for: scoreValue))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                    }

                    Text(kind.resultDescription)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.paddingMedium)
                .cardStyle()

                Button {
                    HapticManager.shared.success()
                    saveAction()
                } label: {
                    Label(didSave ? "Saved to Trends" : "Save Result", systemImage: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.selectedColor, in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(didSave)
            }
            .dsContentLayout()
            .padding(.vertical, 18)
        }
    }
}

private struct AssessmentTrendsSection: View {
    let logs: [AssessmentLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            if logs.isEmpty {
                Text("Saved assessment scores will appear here for trend tracking.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(Theme.paddingMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(logs.prefix(8)) { log in
                    AssessmentLogRow(log: log)
                }
            }
        }
    }
}

private struct AssessmentLogRow: View {
    let log: AssessmentLog

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.assessmentType)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text(log.scoreText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private extension AssessmentLog {
    var scoreText: String {
        if assessmentType == AssessmentKind.maas5.rawValue, let scoreValue {
            return String(format: "%.1f", scoreValue)
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

private struct SymptomItem: Identifiable {
    var id: String { description }
    let description: String
    let symbolName: String
}

private struct SeverityLevel: Identifiable {
    let id = UUID()
    let label: String
    let rangeText: String
    let color: Color
}

private extension AssessmentKind {
    var whatItIs: String {
        switch self {
        case .gad7:
            return "The Generalized Anxiety Disorder 7-item (GAD-7) is a widely recognized, clinically validated screening tool. It measures and tracks the frequency and severity of generalized anxiety symptoms over the past two weeks."
        case .phq8:
            return "The Patient Health Questionnaire 8-item (PHQ-8) is a standardized, clinically validated tool used worldwide to monitor and measure the severity of depressive symptoms over the past two weeks."
        case .pss4:
            return "The Perceived Stress Scale 4-item (PSS-4) is a brief psychological instrument designed to evaluate how unpredictable, uncontrollable, and overloaded you perceive your life circumstances to be."
        case .maas5:
            return "The Mindful Attention Awareness Scale 5-item (MAAS-5) measures a core component of mindfulness—specifically, your receptive awareness of and attention to what is taking place in the present moment."
        }
    }

    var symptomsCovered: [SymptomItem] {
        switch self {
        case .gad7:
            return [
                SymptomItem(description: "Feeling nervous, anxious, or on edge", symbolName: "waveform.path.ecg"),
                SymptomItem(description: "Inability to stop or control worrying", symbolName: "arrow.clockwise"),
                SymptomItem(description: "Worrying too much about different things", symbolName: "bubbles.and.sparkles"),
                SymptomItem(description: "Trouble relaxing and physical restlessness", symbolName: "wind"),
                SymptomItem(description: "Becoming easily annoyed or irritable", symbolName: "exclamationmark.bubble"),
                SymptomItem(description: "Feeling afraid as if something awful might happen", symbolName: "shield.slash")
            ]
        case .phq8:
            return [
                SymptomItem(description: "Little interest or pleasure in doing things", symbolName: "star.slash"),
                SymptomItem(description: "Feeling down, depressed, or hopeless", symbolName: "cloud.rain"),
                SymptomItem(description: "Trouble sleeping (insomnia or oversleeping)", symbolName: "bed.double"),
                SymptomItem(description: "Feeling tired or having little energy", symbolName: "bolt.slash"),
                SymptomItem(description: "Poor appetite or overeating", symbolName: "fork.knife"),
                SymptomItem(description: "Feeling bad about yourself or like a failure", symbolName: "person.text.rectangle"),
                SymptomItem(description: "Trouble concentrating on daily activities", symbolName: "target"),
                SymptomItem(description: "Moving or speaking slowly, or being fidgety", symbolName: "slowmo")
            ]
        case .pss4:
            return [
                SymptomItem(description: "Feeling unable to control important life events", symbolName: "exclamationmark.shield"),
                SymptomItem(description: "Confidence in handling personal difficulties", symbolName: "hand.thumbsup"),
                SymptomItem(description: "Feeling that things are going your way", symbolName: "sun.max"),
                SymptomItem(description: "Feeling difficulties piling up too high to overcome", symbolName: "barometer")
            ]
        case .maas5:
            return [
                SymptomItem(description: "Awareness of emotions as they arise", symbolName: "heart.text.square"),
                SymptomItem(description: "Paying attention to actions to avoid carelessness", symbolName: "hand.raised"),
                SymptomItem(description: "Staying focused on what is happening now", symbolName: "eye"),
                SymptomItem(description: "Performing tasks consciously rather than on 'autopilot'", symbolName: "brain"),
                SymptomItem(description: "Engaging fully in activities without rushing", symbolName: "hourglass.badge.arrow.recenter")
            ]
        }
    }

    var whyItMatters: String {
        switch self {
        case .gad7:
            return "Tracking anxiety symptoms helps you identify specific worries, notice patterns or triggers over time, and evaluate if cognitive reframing or breathing exercises are successfully lowering your daily arousal levels."
        case .phq8:
            return "Regular PHQ-8 tracking provides an objective, long-term snapshot of your emotional health, allowing you to recognize true progress and see beyond minor daily ups and downs."
        case .pss4:
            return "Measuring your subjective stress load is crucial. The PSS-4 helps you identify when life's demands are exceeding your perceived ability to cope, prompting you to prioritize vital self-care."
        case .maas5:
            return "Mindfulness is a key buffer against stress. MAAS-5 tracking shows how often you are living on auto-pilot, encouraging you to anchor in the present moment to reduce excessive worry."
        }
    }

    var scoringRangeText: String {
        switch self {
        case .gad7:
            return "Scores range from 0 to 21. Standard clinical cutoffs indicate the severity of anxiety symptoms:"
        case .phq8:
            return "Scores range from 0 to 24. Standard clinical cutoffs indicate the severity of depressive symptoms:"
        case .pss4:
            return "Scores range from 0 to 16. Higher scores reflect a higher degree of perceived daily stress:"
        case .maas5:
            return "Scores represent the average response on a 1-6 scale. Higher average scores indicate higher mindful awareness:"
        }
    }

    var severityLevels: [SeverityLevel] {
        switch self {
        case .gad7:
            return [
                SeverityLevel(label: "Minimal", rangeText: "0 - 4", color: .green),
                SeverityLevel(label: "Mild", rangeText: "5 - 9", color: .yellow),
                SeverityLevel(label: "Moderate", rangeText: "10 - 14", color: .orange),
                SeverityLevel(label: "Severe", rangeText: "15 - 21", color: .red)
            ]
        case .phq8:
            return [
                SeverityLevel(label: "Minimal", rangeText: "0 - 4", color: .green),
                SeverityLevel(label: "Mild", rangeText: "5 - 9", color: .yellow),
                SeverityLevel(label: "Moderate", rangeText: "10 - 14", color: .orange),
                SeverityLevel(label: "Severe", rangeText: "15 - 24", color: .red)
            ]
        case .pss4:
            return [
                SeverityLevel(label: "Low", rangeText: "0 - 5", color: .green),
                SeverityLevel(label: "Moderate", rangeText: "6 - 10", color: .orange),
                SeverityLevel(label: "High", rangeText: "11 - 16", color: .red)
            ]
        case .maas5:
            return [
                SeverityLevel(label: "Low", rangeText: "1.0 - 2.9", color: .red),
                SeverityLevel(label: "Moderate", rangeText: "3.0 - 4.5", color: .orange),
                SeverityLevel(label: "High", rangeText: "4.6 - 6.0", color: .green)
            ]
        }
    }
}

private struct AssessmentInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    let kind: AssessmentKind

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

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

                            HStack(spacing: 8) {
                                ForEach(kind.severityLevels) { level in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Capsule()
                                            .fill(level.color)
                                            .frame(height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(level.label)
                                                .font(.system(size: 11, design: .rounded).weight(.bold))
                                                .foregroundStyle(Theme.primaryText)
                                                .minimumScaleFactor(0.8)
                                                .lineLimit(1)

                                            Text(level.rangeText)
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(Theme.secondaryText)
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
                    .padding(24)
                }
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
        .presentationDetents([.medium, .large])
    }
}
