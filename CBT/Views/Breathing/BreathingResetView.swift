import SwiftUI

struct BreathingResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var engine: BreathingEngine
    @State private var selectedDuration: Int
    @State private var hasAutoStarted = false
    
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

    var body: some View {
        ZStack {
            // A: Background Layer
            if !hideBackground {
                ThemedBackground().ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // B: Header Setup
                if !hideHeader {
                    headerSection
                }
                
                Spacer()
                
                // C: The Orb centerpiece
                BreathingOrbView(
                    phase: engine.state.phase,
                    isComplete: engine.state.isComplete,
                    accent: accent,
                    pattern: pattern
                )
                .padding(.vertical, 32)
                
                Spacer()
                
                // Completion Controls
                if engine.state.isComplete && !embeddedInFlow {
                    HStack(spacing: DSSpacing.medium) {
                        Button {
                            HapticManager.shared.lightImpact()
                            onComplete?()
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, DSSpacing.xLarge)
                                .padding(.vertical, DSSpacing.medium)
                                .background(accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Finish session")

                        Button {
                            HapticManager.shared.lightImpact()
                            prepareSaveSession()
                        } label: {
                            Label("Journal", systemImage: "square.and.pencil")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, DSSpacing.xLarge)
                                .padding(.vertical, DSSpacing.medium)
                                .background(accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Save to journal")
                    }
                    .padding(.horizontal, 20)
                    .responsiveMaxWidth()
                    .padding(.bottom, DSSpacing.medium)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // D: Controls Dock card
                if showControls {
                    BreathingControlsBar(
                        selectedDuration: $selectedDuration,
                        isRunning: engine.state.isRunning,
                        isComplete: engine.state.isComplete,
                        canResume: shouldShowResume,
                        accent: accent,
                        onStart: {
                            if engine.state.isComplete {
                                engine.stop(resetDurationSeconds: selectedDuration)
                            }
                            sessionStartDate = Date()
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
        .navigationBarHidden(true) // Using custom header for premium feel
        .onChange(of: selectedDuration) { _, newValue in
            engine.setDuration(seconds: newValue)
        }
        .onChange(of: engine.state.phase) { oldValue, newValue in
            handlePhaseChange(from: oldValue, to: newValue)
        }
        .onChange(of: engine.state.isComplete) { _, newValue in
            // Manual dismissal via buttons instead of auto-advance
        }
        .onAppear {
            guard autoStart, !hasAutoStarted else { return }
            hasAutoStarted = true
            engine.stop(resetDurationSeconds: selectedDuration)
            sessionStartDate = Date()
            engine.start()
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
