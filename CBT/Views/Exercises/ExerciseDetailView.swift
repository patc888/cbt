import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let exercise: Exercise
    
    @Query private var completions: [ExerciseCompletion]
    
    @State private var currentStep = 0
    @State private var stepResponses: [String]
    @State private var sessionStartTime: Date?
    
    // Timer state
    @StateObject private var timerManager = TimedSessionManager()
    @State private var showingSaveSession = false
    @State private var completedSummary: SessionSummary?
    
    // Total pages = Overview (1) + Steps (N)
    private var totalPages: Int { exercise.steps.count + 1 }
    
    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseID = exercise.id
        self._completions = Query(filter: #Predicate<ExerciseCompletion> { completion in
            completion.exerciseID == exerciseID && !completion.isDeleted
        })
        self._stepResponses = State(initialValue: Array(repeating: "", count: exercise.steps.count))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Header
                    ProgressView(value: Double(currentStep + 1), total: Double(totalPages))
                        .tint(Theme.primaryColor)
                        .padding()
                        .accessibilityLabel("Step \(currentStep + 1) of \(totalPages)")
                    
                    if timerManager.isRunning || timerManager.isPaused {
                        exerciseTimerBar
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                    
                    TabView(selection: $currentStep) {
                        overviewStepView.tag(0)
                        
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                            stepPageView(index: index, step: step)
                                .tag(index + 1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    
                    // Bottom Navigation
                    HStack {
                        if currentStep > 0 {
                            Button("Back") {
                                withAnimation { currentStep -= 1 }
                            }
                            .foregroundColor(Theme.primaryColor)
                            .padding()
                            .accessibilityLabel("Go back to previous step")
                        } else {
                            Spacer().frame(width: 60)
                        }
                        
                        Spacer()
                        
                        if currentStep < totalPages - 1 {
                            Button(currentStep == 0 ? "Start" : "Next") {
                                if currentStep == 0 {
                                    startExerciseSession()
                                }
                                withAnimation { currentStep += 1 }
                            }
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primaryColor)
                            .clipShape(Capsule())
                            .padding()
                            .accessibilityLabel(currentStep == 0 ? "Start exercise" : "Go to next step")
                        } else {
                            Button("Finish") {
                                markComplete()
                            }
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primaryColor)
                            .clipShape(Capsule())
                            .padding()
                        }
                    }
                    .background(Theme.cardBackground.ignoresSafeArea(edges: .bottom))
                }
            }
            .navigationTitle(exercise.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.selection()
                        dismiss()
                    }
                }
            }
            .onAppear {
                timerManager.onComplete = { summary in
                    var finalSummary = summary
                    finalSummary.bodyText = buildFinalBodyText()
                    completedSummary = finalSummary
                    showingSaveSession = true
                }
            }
            .sheet(isPresented: $showingSaveSession, onDismiss: {
                dismiss()
            }) {
                if let summary = completedSummary {
                    SaveSessionView(summary: summary)
                }
            }
            .onDisappear {
                timerManager.stop()
            }
        }
    }
    
    // MARK: - Flow Views
    
    private var overviewStepView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Overview")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(exercise.description)
                        .font(.body)
                        .foregroundStyle(Theme.secondaryText)
                    
                    HStack(spacing: 12) {
                        Label("\(exercise.steps.count) Steps", systemImage: "list.bullet")
                        Label("\(exercise.duration) min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 8)
                
                Button {
                    startExerciseSession(withTimer: true)
                    withAnimation { currentStep += 1 }
                } label: {
                    Label("Start with \(exercise.duration)m Timer", systemImage: "timer")
                        .bold()
                        .foregroundColor(Theme.primaryColor)
                }
                
                if !completions.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You've completed this \(completions.count) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func stepPageView(index: Int, step: String) -> some View {
        Form {
            Section(header: Text("Stage \(index + 1) of \(exercise.steps.count)")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instruction")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(step)
                        .font(.body)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Reflection")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    Text("Record your thoughts or results for this step.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    
                    TextEditor(text: Binding(
                        get: { index < stepResponses.count ? stepResponses[index] : "" },
                        set: { if index < stepResponses.count { stepResponses[index] = $0 } }
                    ))
                    .frame(minHeight: 180)
                }
                .padding(.vertical, 8)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Timer Bar
    private var exerciseTimerBar: some View {
        HStack(spacing: DSSpacing.medium) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
            }

            Text(timerManager.formattedRemaining)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DSTheme.primaryText)

            Spacer()

            if timerManager.isPaused {
                Button {
                    HapticManager.shared.lightImpact()
                    timerManager.resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resume timer")
            } else {
                Button {
                    HapticManager.shared.lightImpact()
                    timerManager.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause timer")
            }

            Button {
                HapticManager.shared.mediumImpact()
                timerManager.endEarly()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DSTheme.destructive)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop timer")
        }
        .padding(.horizontal, DSSpacing.large)
        .padding(.vertical, DSSpacing.medium)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
    }
    
    private func startExerciseSession(withTimer: Bool = false) {
        if sessionStartTime == nil {
            sessionStartTime = Date()
            if withTimer {
                startExerciseTimer()
            }
        }
    }
    
    // MARK: - Timer
    private func startExerciseTimer() {
        HapticManager.shared.lightImpact()
        let durationSeconds = exercise.duration * 60
        let summary = SessionSummary(
            sourceKind: .exercise,
            sourceID: exercise.id,
            title: exercise.title,
            bodyText: "", // Final bodyText is built on completion
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
            // If timer was running, end it and offer save
            if timerManager.isRunning || timerManager.isPaused {
                timerManager.endEarly()
            } else {
                // Construct a manual summary
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
                showingSaveSession = true
            }
        } catch {
            print("Failed to save exercise completion: \(error)")
        }
    }
}
