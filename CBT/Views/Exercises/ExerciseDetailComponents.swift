import SwiftUI

struct ExerciseFlowProgressHeader: View {
    let currentStep: Int
    let totalPages: Int
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: Double(currentStep + 1), total: Double(totalPages))
                .tint(accent)
            
            Button {
                HapticManager.shared.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(8)
                    .background(Theme.tertiaryBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit exercise")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
        VStack(spacing: 0) {
            Divider()
                .opacity(0.1)
            
            HStack {
                if currentStep > 0 {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(accent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Go back to previous step")
                } else {
                    Spacer().frame(width: 80)
                }

                Spacer()

                if currentStep < totalPages - 1 {
                    Button(action: onNext) {
                        Text(currentStep == 0 ? "Start Session" : "Next Step")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(accent)
                            .clipShape(Capsule())
                            .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
                    }
                    .accessibilityLabel(currentStep == 0 ? "Start exercise" : "Go to next step")
                } else {
                    Button(action: onFinish) {
                        Text("Finish")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.successGreen)
                            .clipShape(Capsule())
                            .shadow(color: Theme.successGreen.opacity(0.3), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.cardBackground.ignoresSafeArea(edges: .bottom))
        }
    }
}

struct ExerciseOverviewPage: View {
    let exercise: Exercise
    let completionsCount: Int
    let accent: Color
    let onStartWithTimer: () -> Void
    let onJumpToBreathing: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Image/Icon placeholder for premium feel
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: categoryIcon(for: exercise.category))
                        .font(.system(size: 48))
                        .foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.2), radius: 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.category.uppercased())
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(accent)
                        .tracking(1.2)
                    
                    Text(exercise.title)
                        .font(DSTypography.pageTitle)
                        .foregroundStyle(Theme.primaryText)
                }

                Text(exercise.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(4)

                if exercise.displayApproach == "DBT" {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(accent)
                        Text("Educational self-help practice, not diagnosis, therapy, treatment, or medical advice.")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if exercise.displayApproaches.contains("ACT") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(accent)
                        Text("Educational self-help only. This is not a replacement for therapy.")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                let approachText = exercise.displayApproaches.joined(separator: ", ")
                if !approachText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(accent)
                        Text("Approach: \(approachText)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        overviewStats
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        overviewStats
                    }
                }

                VStack(spacing: 12) {
                    Button(action: onStartWithTimer) {
                        HStack {
                            Image(systemName: "timer")
                            Text("Start with \(exercise.duration)m Timer")
                        }
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let pattern = exercise.breathingPattern, let onJumpToBreathing {
                        Button(action: onJumpToBreathing) {
                            HStack {
                                Image(systemName: "wind")
                                Text("Guided \(pattern.name)")
                            }
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundColor(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding(.top, 12)

                practiceDetails
            }
            .padding(24)
        }
    }

    private func statCapsule(label: String, icon: String, color: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(color ?? Theme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.tertiaryBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var overviewStats: some View {
        statCapsule(label: "\(exercise.steps.count) Steps", icon: "list.bullet")
        statCapsule(label: "\(exercise.duration) min", icon: "clock")
        statCapsule(label: exercise.displayDifficulty, icon: "flag.fill")
        if completionsCount > 0 {
            statCapsule(label: "\(completionsCount) done", icon: "checkmark.circle.fill", color: .green)
        }
    }

    @ViewBuilder
    private var practiceDetails: some View {
        if hasPracticeDetails {
            VStack(alignment: .leading, spacing: 12) {
                if let completionSummary = exercise.completionSummary, !completionSummary.isEmpty {
                    detailBlock(
                        title: "Completion Summary",
                        icon: "checkmark.seal.fill",
                        text: completionSummary
                    )
                }

                if let journalReflection = exercise.journalReflection, !journalReflection.isEmpty {
                    detailBlock(
                        title: "Journal Reflection",
                        icon: "book.pages.fill",
                        text: journalReflection
                    )
                }

                if let tags = exercise.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var hasPracticeDetails: Bool {
        exercise.completionSummary?.isEmpty == false ||
            exercise.journalReflection?.isEmpty == false ||
            exercise.tags?.isEmpty == false
    }

    private func detailBlock(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Thought Reframing": return "brain.head.profile"
        case "Cognitive Distortions": return "eye.trianglebadge.exclamationmark"
        case "Grounding": return "leaf.fill"
        case "Anxiety Reset": return "wind"
        case "Gratitude": return "heart.fill"
        case "Self Compassion": return "hand.raised.fill"
        case "Mindfulness": return "figure.mind.and.body"
        case "Positive Psychology": return "sparkles"
        case "Distress Tolerance": return "hand.raised.fill"
        case "Emotion Regulation": return "heart.fill"
        case "Self-Soothing": return "sparkles"
        case "Wellness Basics": return "checkmark.circle.fill"
        case "Values": return "safari.fill"
        case "Defusion": return "cloud.fill"
        case "Acceptance": return "hand.raised.fill"
        case "Committed Action": return "checkmark.circle.fill"
        case "Self-as-Context": return "person.crop.circle"
        case "Behavioral Activation": return "figure.walk"
        case "Exposure Practice": return "shield.lefthalf.filled"
        default: return "sparkles"
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Progress Indicator
                HStack {
                    Text("STEP \(stepIndex + 1)")
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Spacer()
                    
                    Text("\(stepIndex + 1) of \(totalSteps)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 10)

                // Instruction Content
                VStack(alignment: .leading, spacing: 16) {
                    Text(step)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Interaction Area
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundStyle(accent)
                        Text("Reflection")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if response.isEmpty {
                            Text("Record your thoughts or results for this step...")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(Theme.secondaryText.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                        }
                        
                        TextEditor(text: $response)
                            .font(.system(.body, design: .rounded))
                            .frame(minHeight: 160)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(accent.opacity(0.1), lineWidth: 1)
                            )
                    }
                }

                if let pattern = breathingPattern, let onJumpToBreathing {
                    Button(action: onJumpToBreathing) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "wind")
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Guided \(pattern.name)")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                Text("Center yourself with this guided session.")
                                    .font(.system(.caption2, design: .rounded))
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: accent.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
    }
}

struct ExerciseTimerBar: View {
    @ObservedObject var timerManager: TimedSessionManager
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.1), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(timerManager.formattedRemaining)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                
                Text("TIME REMAINING")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .tracking(0.5)
            }

            Spacer()

            HStack(spacing: 12) {
                if timerManager.isPaused {
                    timerButton(icon: "play.fill", color: accent) {
                        timerManager.resume()
                    }
                } else {
                    timerButton(icon: "pause.fill", color: accent) {
                        timerManager.pause()
                    }
                }

                timerButton(icon: "stop.fill", color: Theme.errorRed) {
                    timerManager.endEarly()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
    }

    private func timerButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
