import SwiftUI

struct BreathingOrbView: View {
    let phase: BreathingPhase
    let phaseSecondsRemaining: Double
    let isComplete: Bool
    let accent: Color
    let pattern: BreathingPattern
    let isRunning: Bool
    
    private var circleScale: CGFloat {
        if isComplete { return 1.0 }
        switch phase {
        case .inhale: return 1.04
        case .hold1: return 1.04
        case .exhale: return 0.66
        case .hold2: return 0.66
        }
    }
    
    private var glowOpacity: Double {
        if isComplete { return 0.2 }
        switch phase {
        case .inhale: return 0.5
        case .hold1: return 0.4
        case .exhale: return 0.2
        case .hold2: return 0.2
        }
    }
    
    private var phaseProgress: Double {
        guard phaseDuration > 0, !isComplete else { return 1 }
        return min(max(1 - (phaseSecondsRemaining / phaseDuration), 0), 1)
    }

    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(glowOpacity))
                .blur(radius: 42)
                .scaleEffect(circleScale * (isPulsing ? 1.32 : 1.18))

            Circle()
                .stroke(accent.opacity(0.12), lineWidth: 16)
                .frame(width: 306, height: 306)

            Circle()
                .trim(from: 0, to: phaseProgress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 306, height: 306)
                .rotationEffect(.degrees(-90))
                .opacity(isComplete ? 0 : 1)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            accent.opacity(0.78),
                            accent.opacity(0.46)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 180
                     )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                        .padding(1)
                )
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(15)
                        .blur(radius: 20)
                        .opacity(0.6)
                )
                .shadow(color: accent.opacity(0.25), radius: 25, x: 0, y: 15)
                .scaleEffect(circleScale * (isPulsing ? 1.05 : 1.0))
            
            VStack(spacing: 10) {
                Text(countdownText)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
                    .contentTransition(.numericText())

                Text(phaseTitle)
                    .font(DSTypography.pageTitle)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 3)
                    .contentTransition(.opacity)
                
                Text(guidanceText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.opacity)
            }
            .offset(y: -5)
        }
        .frame(width: 320, height: 320)
        .animation(.spring(response: min(max(phaseDuration, 0.7), 4), dampingFraction: 0.82), value: phase)
        .animation(.linear(duration: 0.1), value: phaseSecondsRemaining)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
    
    private var phaseTitle: String {
        if isComplete { return "Complete" }
        if !isRunning { return "Ready" }
        switch phase {
        case .inhale: return "Inhale"
        case .hold1, .hold2: return "Hold"
        case .exhale: return "Exhale"
        }
    }
    
    private var guidanceText: String {
        if isComplete { return "Well done!" }
        if !isRunning { return "Begin when you are ready" }
        switch phase {
        case .inhale: return pattern.inhaleGuidance
        case .hold1: return pattern.hold1Guidance
        case .exhale: return pattern.exhaleGuidance
        case .hold2: return pattern.hold2Guidance
        }
    }
    
    private var phaseDuration: Double {
        switch phase {
        case .inhale: return pattern.inhaleDuration
        case .exhale: return pattern.exhaleDuration
        case .hold1: return pattern.hold1Duration
        case .hold2: return pattern.hold2Duration
        }
    }

    private var countdownText: String {
        if isComplete { return "Done" }
        return "\(max(1, Int(ceil(phaseSecondsRemaining))))"
    }

    private var accessibilityText: String {
        if isComplete { return "Breathing session complete. Well done." }
        return "\(phaseTitle). \(countdownText) seconds. \(guidanceText)."
    }
}
