import SwiftUI

struct BreathingControlsBar: View {
    @Binding var selectedDuration: Int
    @Binding var ambientSound: String

    let isRunning: Bool
    let isComplete: Bool
    let canResume: Bool
    let accent: Color

    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    private let durationOptions = [30, 60, 120, 180]
    private var soundOptions: [String] {
        let soundscapes = LibraryService.shared.bundledAudioContent
            .filter { $0.type == .soundscape }
            .map { Self.resourceName(from: $0.localAssetFilename) }

        return ["None"] + soundscapes
    }

    var body: some View {
        VStack(spacing: DSSpacing.large) {
            VStack(alignment: .leading, spacing: DSSpacing.small) {
                Text("Duration")
                    .font(DSTypography.caption)
                    .foregroundStyle(DSTheme.secondaryText)

                SegmentedToggle(
                    selection: $selectedDuration,
                    options: durationOptions,
                    fontSize: 13,
                    verticalPadding: 8,
                    activeColor: accent
                ) { duration in
                    Text(formatDuration(duration))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .disabled(isRunning)
                .opacity(isRunning ? 0.5 : 1)
                .accessibilityLabel("Session duration")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DSSpacing.medium) {
                    soundMenu
                    primaryControlButton
                    stopButton
                }

                VStack(spacing: DSSpacing.small) {
                    soundMenu
                    HStack(spacing: DSSpacing.medium) {
                        primaryControlButton
                        stopButton
                    }
                }
            }
        }
        .padding(DSSpacing.large)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                .strokeBorder(DSTheme.separator.opacity(0.2), lineWidth: 0.8)
        }
    }

    private var soundMenu: some View {
        Menu {
            ForEach(soundOptions, id: \.self) { sound in
                Button {
                    HapticManager.shared.lightImpact()
                    ambientSound = sound
                } label: {
                    HStack {
                        Text(sound)
                        if ambientSound == sound {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(ambientSound == "None" ? "Sound" : ambientSound, systemImage: ambientSound == "None" ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 132)
        }
        .buttonStyle(DSSecondaryButtonStyle())
        .disabled(isRunning)
        .opacity(isRunning ? 0.5 : 1)
        .accessibilityLabel("Ambient sound: \(ambientSound)")
    }

    private var primaryControlButton: some View {
        Group {
            if isRunning {
                Button(action: onPause) {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityLabel("Pause breathing session")
            } else {
                Button(action: onStart) {
                    Label(isComplete ? "Restart" : (canResume ? "Resume" : "Start"),
                          systemImage: isComplete ? "arrow.clockwise" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .accessibilityLabel(isComplete ? "Restart session" : (canResume ? "Resume session" : "Start session"))
            }
        }
    }

    @ViewBuilder
    private var stopButton: some View {
        if isRunning || canResume {
            Button(action: onStop) {
                Image(systemName: "xmark")
                    .font(.system(.body, weight: .bold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(BreathingResetButtonStyle())
            .accessibilityLabel("Stop and reset")
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }

    private static func resourceName(from fileName: String) -> String {
        URL(fileURLWithPath: fileName)
            .deletingPathExtension()
            .lastPathComponent
    }
}

private struct BreathingResetButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DSTheme.destructive)
            .background(DSTheme.destructive.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
    }
}
