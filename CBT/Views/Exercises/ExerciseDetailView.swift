import SwiftUI
import SwiftData
import os

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let exercise: Exercise

    @State private var completions: [ExerciseCompletion] = []

    @State private var currentStep = 0
    @State private var stepResponses: [String]
    @State private var sessionStartTime: Date?

    @StateObject private var timerManager = TimedSessionManager()
    @State private var completedSummary: SessionSummary?

    private var totalPages: Int {
        var count = exercise.steps.count + 1
        if exercise.breathingPattern != nil { count += 1 }
        return count
    }

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    init(exercise: Exercise) {
        self.exercise = exercise
        self._stepResponses = State(initialValue: Array(repeating: "", count: exercise.steps.count))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ThemedBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ExerciseFlowProgressHeader(
                    currentStep: currentStep,
                    totalPages: totalPages,
                    accent: accent
                )

                if timerManager.isRunning || timerManager.isPaused {
                    ExerciseTimerBar(
                        timerManager: timerManager,
                        accent: accent
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }

                TabView(selection: $currentStep) {
                    ExerciseOverviewPage(
                        exercise: exercise,
                        completionsCount: completions.count,
                        accent: accent,
                        onStartWithTimer: {
                            startExerciseSession(withTimer: true)
                            withAnimation { currentStep += 1 }
                        },
                        onJumpToBreathing: exercise.breathingPattern == nil ? nil : {
                            HapticManager.shared.mediumImpact()
                            withAnimation {
                                currentStep = 1
                            }
                        }
                    )
                    .tag(0)

                    if let pattern = exercise.breathingPattern {
                        ExerciseBreathingPage(exercise: exercise, pattern: pattern)
                            .tag(1)
                    }

                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                        ExerciseInstructionPage(
                            stepIndex: index,
                            totalSteps: exercise.steps.count,
                            step: step,
                            response: responseBinding(for: index),
                            breathingPattern: exercise.breathingPattern,
                            accent: accent,
                            onJumpToBreathing: exercise.breathingPattern == nil ? nil : {
                                HapticManager.shared.mediumImpact()
                                withAnimation {
                                    currentStep = 1
                                }
                            }
                        )
                        .tag(stepTag(forIndex: index))
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut, value: currentStep)

                ExerciseFlowNavigationBar(
                    currentStep: currentStep,
                    totalPages: totalPages,
                    accent: accent,
                    onBack: {
                        withAnimation { currentStep -= 1 }
                    },
                    onNext: {
                        if currentStep == 0 {
                            startExerciseSession()
                        }
                        withAnimation { currentStep += 1 }
                    },
                    onFinish: markComplete
                )
            }
        }
        .navigationTitle(exercise.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            NotificationCenter.default.post(name: .exerciseFlowDidEnter, object: nil)
            refreshCompletions()
            timerManager.onComplete = { summary in
                var finalSummary = summary
                finalSummary.bodyText = buildFinalBodyText()
                completedSummary = finalSummary
            }
        }
        .navigationDestination(item: $completedSummary) { summary in
            SaveSessionView(summary: summary, onSaveComplete: { dismiss() })
        }
        .onDisappear {
            NotificationCenter.default.post(name: .exerciseFlowDidExit, object: nil)
            timerManager.stop()
        }
    }

    private func stepTag(forIndex index: Int) -> Int {
        var tag = index + 1
        if exercise.breathingPattern != nil { tag += 1 }
        return tag
    }

    private func responseBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < stepResponses.count ? stepResponses[index] : "" },
            set: { newValue in
                guard index < stepResponses.count else { return }
                stepResponses[index] = newValue
            }
        )
    }

    private func startExerciseSession(withTimer: Bool = false) {
        if sessionStartTime == nil {
            sessionStartTime = Date()
            if withTimer {
                startExerciseTimer()
            }
        }
    }

    private func startExerciseTimer() {
        HapticManager.shared.lightImpact()
        let durationSeconds = exercise.duration * 60
        let summary = SessionSummary(
            sourceKind: .exercise,
            sourceID: exercise.id,
            title: exercise.title,
            bodyText: "",
            durationSeconds: durationSeconds,
            startedAt: Date(),
            endedAt: Date()
        )
        timerManager.start(durationSeconds: durationSeconds, summary: summary)
    }

    private func buildFinalBodyText() -> String {
        var bodyText = "\(exercise.description)\n\n"
        for (index, step) in exercise.steps.enumerated() {
            bodyText += "Step \(index + 1): \(step)\n"
            if index < stepResponses.count {
                let response = stepResponses[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !response.isEmpty {
                    bodyText += "My Notes:\n\(response)\n"
                }
            }
            bodyText += "\n"
        }
        return bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markComplete() {
        let newCompletion = ExerciseCompletion(
            exerciseID: exercise.id
        )
        modelContext.insert(newCompletion)

        do {
            try modelContext.save()
            refreshCompletions()
            ReviewManager.shared.logSignificantAction()
            if timerManager.isRunning || timerManager.isPaused {
                timerManager.endEarly()
            } else {
                let start = sessionStartTime ?? Date()
                let elapsed = Int(Date().timeIntervalSince(start))
                let summary = SessionSummary(
                    sourceKind: .exercise,
                    sourceID: exercise.id,
                    title: exercise.title,
                    bodyText: buildFinalBodyText(),
                    durationSeconds: elapsed,
                    startedAt: start,
                    endedAt: Date()
                )
                completedSummary = summary
            }
        } catch {
            AppLogger.make(category: "Data").error("Failed to save exercise completion: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    private func refreshCompletions() {
        completions = LaunchSafeFetch.exerciseCompletions(
            for: exercise.id,
            from: modelContext
        )
    }
}
