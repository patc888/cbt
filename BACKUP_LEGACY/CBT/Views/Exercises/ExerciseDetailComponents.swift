import SwiftUI

struct ExerciseFlowProgressHeader: View {
    let currentStep: Int
    let totalPages: Int
    let accent: Color

    var body: some View {
        ProgressView(value: Double(currentStep + 1), total: Double(totalPages))
            .tint(accent)
            .padding()
            .accessibilityLabel("Step \(currentStep + 1) of \(totalPages)")
    }
}

struct ExerciseFlowNavigationBar: View {
    let currentStep: Int
    let totalPages: Int
    let accent: Color
    let onBack: () -> Void
    let onNext: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack {
            if currentStep > 0 {
                Button("Back", action: onBack)
                    .foregroundColor(accent)
                    .padding()
                    .accessibilityLabel("Go back to previous step")
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            if currentStep < totalPages - 1 {
                Button(currentStep == 0 ? "Start" : "Next", action: onNext)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(Capsule())
                    .padding()
                    .accessibilityLabel(currentStep == 0 ? "Start exercise" : "Go to next step")
            } else {
                Button("Finish", action: onFinish)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accent)
                    .clipShape(Capsule())
                    .padding()
            }
        }
        .background(Theme.cardBackground.ignoresSafeArea(edges: .bottom))
    }
}

struct ExerciseOverviewPage: View {
    let exercise: Exercise
    let completionsCount: Int
    let accent: Color
    let onStartWithTimer: () -> Void
    let onJumpToBreathing: (() -> Void)?

    var body: some View {
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

                Button(action: onStartWithTimer) {
                    Label("Start with \(exercise.duration)m Timer", systemImage: "timer")
                        .bold()
                        .foregroundColor(accent)
                }

                if let pattern = exercise.breathingPattern, let onJumpToBreathing {
                    Button(action: onJumpToBreathing) {
                        Label("Guided \(pattern.name)", systemImage: "wind")
                            .bold()
                            .foregroundColor(accent)
                    }
                }

                if completionsCount > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You've completed this \(completionsCount) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct ExerciseBreathingPage: View {
    let exercise: Exercise
    let pattern: BreathingPattern

    var body: some View {
        VStack(spacing: 0) {
            BreathingResetView(
                durationSeconds: exercise.duration * 60,
                pattern: pattern,
                autoStart: true,
                showsDismissControl: false,
                showControls: true,
                hideBackground: true,
                hideHeader: true,
                onComplete: {
                    // Intentionally no auto-advance to keep the transition user-driven.
                },
                embeddedInFlow: true
            )
        }
    }
}

struct ExerciseInstructionPage: View {
    let stepIndex: Int
    let totalSteps: Int
    let step: String
    @Binding var response: String
    let breathingPattern: BreathingPattern?
    let accent: Color
    let onJumpToBreathing: (() -> Void)?

    var body: some View {
        Form {
            Section(header: Text("Stage \(stepIndex + 1) of \(totalSteps)")) {
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

                    TextEditor(text: $response)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.vertical, 8)

                if let pattern = breathingPattern, let onJumpToBreathing {
                    Button(action: onJumpToBreathing) {
                        HStack {
                            Image(systemName: "wind")
                            VStack(alignment: .leading) {
                                Text("Guided \(pattern.name)")
                                    .font(.subheadline.bold())
                                Text("Center yourself with this guided session.")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct ExerciseTimerBar: View {
    @ObservedObject var timerManager: TimedSessionManager
    let accent: Color

    var body: some View {
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
}
