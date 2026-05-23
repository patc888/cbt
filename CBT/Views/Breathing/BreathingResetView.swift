import SwiftUI
import SwiftData

struct BreathingResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    @StateObject private var engine: BreathingEngine
    @State private var selectedDuration: Int
    @State private var hasAutoStarted = false
    @State private var ambientSound: String = "None"

    // Journal save state
    @State private var completedSummary: SessionSummary?
    @State private var sessionStartDate: Date?

    let pattern: BreathingPattern
    let autoStart: Bool
    let showsDismissControl: Bool
    let showControls: Bool
    let hideBackground: Bool
    let hideHeader: Bool
    let onComplete: (() -> Void)?
    let onDismiss: (() -> Void)?
    /// When true, view is embedded (e.g. in exercise flow): no dismiss on complete, no bottom safe area inset.
    let embeddedInFlow: Bool

    init(
        durationSeconds: Int = 60,
        pattern: BreathingPattern = .box,
        autoStart: Bool = false,
        showsDismissControl: Bool = false,
        showControls: Bool = true,
        hideBackground: Bool = false,
        hideHeader: Bool = false,
        onComplete: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        embeddedInFlow: Bool = false
    ) {
        let safeDuration = max(1, durationSeconds)
        _engine = StateObject(wrappedValue: BreathingEngine(durationSeconds: safeDuration, pattern: pattern))
        _selectedDuration = State(initialValue: safeDuration)
        self.pattern = pattern
        self.autoStart = autoStart
        self.showsDismissControl = showsDismissControl
        self.showControls = showControls
        self.hideBackground = hideBackground
        self.hideHeader = hideHeader
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        self.embeddedInFlow = embeddedInFlow
    }

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var shouldShowResume: Bool {
        !engine.state.isRunning &&
        !engine.state.isComplete &&
        engine.state.totalSecondsRemaining < selectedDuration
    }

    private var sessionProgress: Double {
        guard selectedDuration > 0 else { return 0 }
        let elapsed = selectedDuration - engine.state.totalSecondsRemaining
        return min(max(Double(elapsed) / Double(selectedDuration), 0), 1)
    }

    var body: some View {
        ZStack {
            if !hideBackground {
                ThemedBackground().ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if !hideHeader {
                    headerSection
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DSSpacing.xLarge) {
                        sessionProgressSection

                        BreathingOrbView(
                            phase: engine.state.phase,
                            phaseSecondsRemaining: engine.state.phaseSecondsRemaining,
                            isComplete: engine.state.isComplete,
                            accent: accent,
                            pattern: pattern,
                            isRunning: engine.state.isRunning
                        )
                        .padding(.top, hideHeader ? DSSpacing.large : DSSpacing.small)

                        breathingCueSection
                        phaseTimeline
                    }
                    .dsScreenContent(
                        maxWidth: 620,
                        horizontalPadding: 20,
                        bottomPadding: showControls ? DSSpacing.large : DSSpacing.xxLarge
                    )
                }

                if engine.state.isComplete && !embeddedInFlow {
                    HStack(spacing: DSSpacing.medium) {
                        Button {
                            HapticManager.shared.lightImpact()
                            onComplete?()
                            dismiss()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        .accessibilityLabel("Finish session")

                        Button {
                            HapticManager.shared.lightImpact()
                            prepareSaveSession()
                        } label: {
                            Label("Journal", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(DSSecondaryButtonStyle())
                        .accessibilityLabel("Save to journal")
                    }
                    .padding(.horizontal, 20)
                    .responsiveMaxWidth()
                    .padding(.bottom, DSSpacing.medium)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showControls {
                    BreathingControlsBar(
                        selectedDuration: $selectedDuration,
                        ambientSound: $ambientSound,
                        isRunning: engine.state.isRunning,
                        isComplete: engine.state.isComplete,
                        canResume: shouldShowResume,
                        accent: accent,
                        onStart: {
                            if engine.state.isComplete {
                                engine.stop(resetDurationSeconds: selectedDuration)
                            }
                            if sessionStartDate == nil || engine.state.totalSecondsRemaining == selectedDuration {
                                sessionStartDate = Date()
                            }
                            engine.start()
                        },
                        onPause: {
                            engine.pause()
                        },
                        onStop: {
                            engine.stop(resetDurationSeconds: selectedDuration)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .responsiveMaxWidth()
                }
            }
        }
        .modifier(EmbeddedFlowBottomInset(embeddedInFlow: embeddedInFlow))
        #if os(iOS)
        .navigationBarHidden(true) // Using custom header for premium feel
        #endif
        .onChange(of: selectedDuration) { _, newValue in
            engine.setDuration(seconds: newValue)
        }
        .onChange(of: ambientSound) { _, newValue in
            engine.toggleAmbientSound(named: newValue, isOn: newValue != "None")
        }
        .onChange(of: engine.currentAmbientSound) { _, newValue in
            if ambientSound != newValue {
                ambientSound = newValue
            }
        }
        .onChange(of: engine.state.phase) { oldValue, newValue in
            handlePhaseChange(from: oldValue, to: newValue)
        }
        .onChange(of: engine.state.isComplete) { _, newValue in
            if newValue {
                HapticManager.shared.success()

                // Save a BreathingSession to SwiftData
                let session = BreathingSession(durationSeconds: selectedDuration)
                modelContext.insert(session)
            }
        }
        .onAppear {
            if autoStart, !hasAutoStarted {
                hasAutoStarted = true
                engine.stop(resetDurationSeconds: selectedDuration)
                sessionStartDate = Date()
                engine.start()
            }
            // Restore sound if needed
            ambientSound = engine.currentAmbientSound
        }
        .sheet(item: $completedSummary) { summary in
            SaveSessionView(summary: summary)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.name)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)

                Text("\(formattedTime(engine.state.totalSecondsRemaining)) remaining")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }

            Spacer()

            if showsDismissControl {
                Button {
                    onDismiss?()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(DSTheme.secondaryText)
                        .padding(10)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pattern.name). \(formattedTime(engine.state.totalSecondsRemaining)) remaining.")
    }

    private var sessionProgressSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                Label(sessionStatusText, systemImage: sessionStatusIcon)
                    .font(DSTypography.caption)
                    .foregroundStyle(accent)

                Spacer()

                Text(formattedTime(engine.state.totalSecondsRemaining))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(DSTheme.primaryText)
            }

            ProgressView(value: sessionProgress)
                .tint(accent)
                .accessibilityLabel("Breathing session progress")
                .accessibilityValue("\(Int((sessionProgress * 100).rounded())) percent")
        }
        .padding(DSSpacing.large)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.2), lineWidth: 0.8)
        }
        .padding(.top, hideHeader ? DSSpacing.large : DSSpacing.small)
    }

    private var breathingCueSection: some View {
        VStack(spacing: DSSpacing.small) {
            Text(currentGuidanceTitle)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Text(currentGuidanceBody)
                .font(DSTypography.body)
                .foregroundStyle(DSTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, DSSpacing.large)
        .animation(.easeInOut(duration: 0.2), value: engine.state.phase)
        .animation(.easeInOut(duration: 0.2), value: engine.state.isComplete)
    }

    private var phaseTimeline: some View {
        HStack(spacing: DSSpacing.small) {
            ForEach(Array(visiblePhases.enumerated()), id: \.offset) { _, phaseInfo in
                VStack(spacing: DSSpacing.xSmall) {
                    Text(phaseInfo.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(engine.state.phase == phaseInfo.phase && !engine.state.isComplete ? .white : DSTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(Int(phaseInfo.duration))s")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(engine.state.phase == phaseInfo.phase && !engine.state.isComplete ? .white.opacity(0.85) : DSTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.small)
                .background(engine.state.phase == phaseInfo.phase && !engine.state.isComplete ? accent : DSTheme.elevatedFill)
                .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: engine.state.phase)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Breathing pattern: \(visiblePhases.map { "\($0.title) \(Int($0.duration)) seconds" }.joined(separator: ", "))")
    }

    private var visiblePhases: [(phase: BreathingPhase, title: String, duration: Double)] {
        [
            (.inhale, "Inhale", pattern.inhaleDuration),
            (.hold1, "Hold", pattern.hold1Duration),
            (.exhale, "Exhale", pattern.exhaleDuration),
            (.hold2, "Rest", pattern.hold2Duration)
        ].filter { $0.duration > 0 }
    }

    private var currentGuidanceTitle: String {
        if engine.state.isComplete { return "Notice the shift" }
        if !engine.state.isRunning && !shouldShowResume { return "Settle in" }
        if shouldShowResume { return "Pick up gently" }

        switch engine.state.phase {
        case .inhale: return "Breathe in"
        case .hold1: return "Hold softly"
        case .exhale: return "Let it out"
        case .hold2: return "Rest in the pause"
        }
    }

    private var currentGuidanceBody: String {
        if engine.state.isComplete {
            return "Take one natural breath and notice what feels a little steadier."
        }
        if !engine.state.isRunning && !shouldShowResume {
            return "Let your shoulders drop. When you start, match your breath to the expanding circle."
        }
        if shouldShowResume {
            return "Resume when it feels right, or reset and begin again from the top."
        }

        switch engine.state.phase {
        case .inhale: return pattern.inhaleGuidance
        case .hold1: return pattern.hold1Guidance
        case .exhale: return pattern.exhaleGuidance
        case .hold2: return pattern.hold2Guidance
        }
    }

    private var sessionStatusText: String {
        if engine.state.isComplete { return "Complete" }
        if engine.state.isRunning { return "Guided session" }
        if shouldShowResume { return "Paused" }
        return "Ready"
    }

    private var sessionStatusIcon: String {
        if engine.state.isComplete { return "checkmark.circle.fill" }
        if engine.state.isRunning { return "wind" }
        if shouldShowResume { return "pause.circle.fill" }
        return "sparkles"
    }

    // MARK: - Sub-logic
    private func handlePhaseChange(from oldPhase: BreathingPhase, to newPhase: BreathingPhase) {
        guard engine.state.isRunning, oldPhase != newPhase else { return }

        // Haptic logic (6: Optional, safe)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        switch newPhase {
        case .inhale:
            HapticManager.shared.trigger(.light)
        case .exhale:
            HapticManager.shared.trigger(.selection) // Custom soft-ish feel
        default:
            HapticManager.shared.trigger(.lightTick)
        }
        #endif
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }

    private func prepareSaveSession() {
        let elapsed = selectedDuration - engine.state.totalSecondsRemaining
        let start = sessionStartDate ?? Date().addingTimeInterval(TimeInterval(-elapsed))
        let summary = SessionSummary(
            sourceKind: .breathing,
            sourceID: "breathing-\(pattern.name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            title: pattern.name,
            bodyText: "\(pattern.name) session — \(formattedTime(selectedDuration)) duration",
            durationSeconds: elapsed,
            startedAt: start,
            endedAt: Date()
        )
        completedSummary = summary
    }
}

// MARK: - Embedded flow layout
private struct EmbeddedFlowBottomInset: ViewModifier {
    let embeddedInFlow: Bool
    func body(content: Content) -> some View {
        if embeddedInFlow {
            content
        } else {
            content.safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BreathingResetView(pattern: .box)
    }
}
