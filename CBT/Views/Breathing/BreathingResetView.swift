import SwiftUI

struct BreathingResetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var engine: BreathingEngine
    @State private var selectedDuration: Int
    @State private var soundEnabled = false
    @State private var soundManager = BreathingSoundManager()
    @State private var hasAutoStarted = false
    
    // Journal save state
    @State private var showingSaveSession = false
    @State private var completedSummary: SessionSummary?
    @State private var sessionStartDate: Date?

    let autoStart: Bool
    let showsDismissControl: Bool

    init(durationSeconds: Int = 60, autoStart: Bool = false, showsDismissControl: Bool = false) {
        let safeDuration = max(1, durationSeconds)
        _engine = StateObject(wrappedValue: BreathingEngine(durationSeconds: safeDuration))
        _selectedDuration = State(initialValue: safeDuration)
        self.autoStart = autoStart
        self.showsDismissControl = showsDismissControl
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
            ThemedBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // B: Header Setup
                headerSection
                
                Spacer()
                
                // C: The Orb centerpiece
                BreathingOrbView(
                    phase: engine.state.phase,
                    isComplete: engine.state.isComplete,
                    accent: accent
                )
                .padding(.vertical, 32)
                
                Spacer()
                
                // Save to Journal button (shown only when complete)
                if engine.state.isComplete {
                    Button {
                        HapticManager.shared.lightImpact()
                        prepareSaveSession()
                    } label: {
                        Label("Save to Journal", systemImage: "square.and.pencil")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, DSSpacing.xLarge)
                            .padding(.vertical, DSSpacing.medium)
                            .background(accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save this session to your journal")
                    .padding(.bottom, DSSpacing.medium)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // D: Controls Dock card
                BreathingControlsBar(
                    selectedDuration: $selectedDuration,
                    soundEnabled: $soundEnabled,
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
        }
        .navigationBarHidden(true) // Using custom header for premium feel
        .onChange(of: selectedDuration) { _, newValue in
            engine.setDuration(seconds: newValue)
        }
        .onChange(of: engine.state.phase) { oldValue, newValue in
            handlePhaseChange(from: oldValue, to: newValue)
        }
        .onAppear {
            guard autoStart, !hasAutoStarted else { return }
            hasAutoStarted = true
            engine.stop(resetDurationSeconds: selectedDuration)
            sessionStartDate = Date()
            engine.start()
        }
        .sheet(isPresented: $showingSaveSession) {
            if let summary = completedSummary {
                SaveSessionView(summary: summary)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Breathing Reset")
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(DSTheme.primaryText)
                
                Text("Box breathing • \(formattedTime(engine.state.totalSecondsRemaining))")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)
            }
            
            Spacer()
            
            if showsDismissControl {
                Button {
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
        .accessibilityLabel("Breathing Reset. Box breathing session. \(formattedTime(engine.state.totalSecondsRemaining)) remaining.")
    }

    // MARK: - Sub-logic
    private func handlePhaseChange(from oldPhase: BreathingPhase, to newPhase: BreathingPhase) {
        guard engine.state.isRunning, oldPhase != newPhase else { return }
        
        // Sound logic
        if soundEnabled {
            soundManager.playPhaseChange()
        }
        
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
            sourceID: "breathing-box",
            title: "Breathing Reset",
            bodyText: "Box breathing session — \(formattedTime(selectedDuration)) duration",
            durationSeconds: elapsed,
            startedAt: start,
            endedAt: Date()
        )
        completedSummary = summary
        showingSaveSession = true
    }
}

#Preview {
    NavigationStack {
        BreathingResetView()
    }
}
