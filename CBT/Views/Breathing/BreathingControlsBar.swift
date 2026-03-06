import SwiftUI

struct BreathingControlsBar: View {
    @Binding var selectedDuration: Int
    let isRunning: Bool
    let isComplete: Bool
    let canResume: Bool
    let accent: Color
    
    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Settings Row
            HStack(spacing: 12) {
                // Duration Selection
                HStack(spacing: 0) {
                    ForEach([30, 60, 120], id: \.self) { duration in
                        Button {
                            HapticManager.shared.lightImpact()
                            selectedDuration = duration
                        } label: {
                            Text(formatDuration(duration))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedDuration == duration ? accent : Color.clear)
                                .foregroundStyle(selectedDuration == duration ? .white : .primary)
                        }
                        .disabled(isRunning)
                        .accessibilityLabel("\(formatDuration(duration)) duration")
                        .accessibilityAddTraits(selectedDuration == duration ? .isSelected : [])
                    }
                }
                .background(Color(.secondarySystemFill))
                .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Interaction Row
            HStack(spacing: 16) {
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
                
                if isRunning || canResume {
                    Button(action: onStop) {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .bold))
                            .padding(16)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop and reset")
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }
}
