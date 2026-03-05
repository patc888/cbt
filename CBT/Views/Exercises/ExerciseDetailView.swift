import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    
    let exercise: Exercise
    
    @Query private var completions: [ExerciseCompletion]
    
    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseID = exercise.id
        self._completions = Query(filter: #Predicate<ExerciseCompletion> { completion in
            completion.exerciseID == exerciseID && !completion.isDeleted
        })
    }
    
    @State private var isStarted = false
    
    // Timer state
    @StateObject private var timerManager = TimedSessionManager()
    @State private var showingSaveSession = false
    @State private var completedSummary: SessionSummary?
    
    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(exercise.title)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(Theme.primaryText)
                        
                        Spacer()
                        
                        if !completions.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Completed")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top)
                    
                    Text(exercise.description)
                        .font(.body)
                        .foregroundColor(Theme.secondaryText)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                        Text("\(exercise.duration) min")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
                    
                    // Timer bar (if running)
                    if timerManager.isRunning || timerManager.isPaused {
                        exerciseTimerBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                        
                    if !isStarted {
                        VStack(spacing: 12) {
                            Button {
                                withAnimation {
                                    isStarted = true
                                }
                            } label: {
                                Text("Start Exercise")
                                    .font(.headline)
                                    .foregroundColor(Theme.backgroundColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.secondaryColor)
                                    .cornerRadius(12)
                            }
                            
                            // Start with Timer button
                            if !timerManager.isRunning {
                                Button {
                                    withAnimation {
                                        isStarted = true
                                    }
                                    startExerciseTimer()
                                } label: {
                                    Label("Start with \(exercise.duration)m Timer", systemImage: "timer")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(accent)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(accent.opacity(0.12))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.top)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(Theme.backgroundColor)
                                        .frame(width: 28, height: 28)
                                        .background(Theme.primaryColor)
                                        .clipShape(Circle())
                                    
                                    Text(step)
                                        .font(.body)
                                        .foregroundColor(Theme.primaryText)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        // Start timer from steps view
                        if !timerManager.isRunning && !timerManager.isPaused {
                            Button {
                                startExerciseTimer()
                            } label: {
                                Label("Start Timer (\(exercise.duration)m)", systemImage: "timer")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(accent.opacity(0.12))
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button {
                            markComplete()
                        } label: {
                            Text("Mark Complete")
                                .font(.headline)
                                .foregroundColor(Theme.backgroundColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primaryColor)
                                .cornerRadius(12)
                        }
                        .padding(.top)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .responsiveMaxWidth()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
#if os(iOS)
        .toolbarBackground(Theme.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        .onAppear {
            timerManager.onComplete = { summary in
                completedSummary = summary
                showingSaveSession = true
            }
        }
        .sheet(isPresented: $showingSaveSession) {
            if let summary = completedSummary {
                SaveSessionView(summary: summary)
            }
        }
        .onDisappear {
            timerManager.stop()
        }
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
        }
        .padding(.horizontal, DSSpacing.large)
        .padding(.vertical, DSSpacing.medium)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
    }
    
    // MARK: - Timer
    private func startExerciseTimer() {
        HapticManager.shared.lightImpact()
        let durationSeconds = exercise.duration * 60
        let bodyText = """
        \(exercise.description)
        
        Steps:
        \(exercise.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """
        let summary = SessionSummary(
            sourceKind: .exercise,
            sourceID: exercise.id,
            title: exercise.title,
            bodyText: bodyText,
            durationSeconds: durationSeconds,
            startedAt: Date(),
            endedAt: Date()
        )
        timerManager.start(durationSeconds: durationSeconds, summary: summary)
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
            }
            dismiss()
        } catch {
            print("Failed to save exercise completion: \(error)")
        }
    }
}
