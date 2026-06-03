import SwiftUI

struct TimedSessionSheet: View {
    @ObservedObject var manager: TimedSessionManager
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    var onEndEarly: () -> Void = {}
    var onSwitchToBreathing: () -> Void = BreathingPresenter.presentOneMinuteReset

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        VStack(spacing: DSSpacing.large) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 6)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: manager.progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: manager.progress)

                VStack(spacing: 2) {
                    Text(manager.formattedRemaining)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DSTheme.primaryText)
                        .monospacedDigit()

                    if let summary = manager.summary {
                        Text(summary.sourceKind.displayName)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                    }
                }
            }
            .padding(.top, DSSpacing.xLarge)

            // Controls
            HStack(spacing: DSSpacing.large) {
                if manager.isPaused {
                    Button {
                        HapticManager.shared.lightImpact()
                        manager.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(DSButtonStyle(variant: .primary, size: .medium, expands: false, tint: accent, hapticType: nil))
                } else if manager.isRunning {
                    Button {
                        HapticManager.shared.lightImpact()
                        manager.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .medium, expands: false, tint: accent, hapticType: nil))
                }

                Button {
                    HapticManager.shared.mediumImpact()
                    manager.endEarly()
                    onEndEarly()
                } label: {
                    Label("End", systemImage: "stop.fill")
                }
                .buttonStyle(DSButtonStyle(variant: .destructive, size: .medium, expands: false, hapticType: nil))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.large)
        .sessionBoundaryDialog(
            manager: manager,
            onSaveAndClose: onEndEarly,
            onSwitchToBreathing: onSwitchToBreathing
        )
    }
}

struct SessionBoundaryDialogModifier: ViewModifier {
    @ObservedObject var manager: TimedSessionManager
    var onSaveAndClose: () -> Void
    var onSwitchToBreathing: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                String(localized: "Gentle stop"),
                isPresented: $manager.isBoundaryPromptPresented,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Save and close")) {
                    HapticManager.shared.mediumImpact()
                    manager.endEarly()
                    onSaveAndClose()
                }

                Button(String(localized: "Switch to breathing")) {
                    HapticManager.shared.lightImpact()
                    manager.stop()
                    onSwitchToBreathing()
                }

                Button(String(localized: "Continue")) {
                    HapticManager.shared.lightImpact()
                    manager.continueAfterBoundaryPrompt()
                }
            } message: {
                Text(String(localized: "You reached the session boundary you set. Would it help to close this, reset with breathing, or keep going?"))
            }
    }
}

extension View {
    func sessionBoundaryDialog(
        manager: TimedSessionManager,
        onSaveAndClose: @escaping () -> Void = {},
        onSwitchToBreathing: @escaping () -> Void = BreathingPresenter.presentOneMinuteReset
    ) -> some View {
        modifier(
            SessionBoundaryDialogModifier(
                manager: manager,
                onSaveAndClose: onSaveAndClose,
                onSwitchToBreathing: onSwitchToBreathing
            )
        )
    }
}
