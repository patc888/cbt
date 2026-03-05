import SwiftUI

struct TimedSessionSheet: View {
    @ObservedObject var manager: TimedSessionManager
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    var onEndEarly: () -> Void = {}

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
                            .font(DSTypography.button)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DSSpacing.xLarge)
                            .padding(.vertical, DSSpacing.medium)
                            .background(accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if manager.isRunning {
                    Button {
                        HapticManager.shared.lightImpact()
                        manager.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .font(DSTypography.button)
                            .foregroundStyle(accent)
                            .padding(.horizontal, DSSpacing.xLarge)
                            .padding(.vertical, DSSpacing.medium)
                            .background(accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    HapticManager.shared.mediumImpact()
                    manager.endEarly()
                    onEndEarly()
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .font(DSTypography.button)
                        .foregroundStyle(DSTheme.destructive)
                        .padding(.horizontal, DSSpacing.xLarge)
                        .padding(.vertical, DSSpacing.medium)
                        .background(DSTheme.destructive.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.large)
    }
}
