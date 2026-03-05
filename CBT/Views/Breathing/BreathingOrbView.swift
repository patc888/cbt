import SwiftUI

struct BreathingOrbView: View {
    let phase: BreathingPhase
    let isComplete: Bool
    let accent: Color
    
    private var circleScale: CGFloat {
        if isComplete { return 1.0 }
        switch phase {
        case .inhale: return 1.0
        case .hold1: return 1.0
        case .exhale: return 0.65
        case .hold2: return 0.65
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
    
    var body: some View {
        ZStack {
            // Outer Glow
            Circle()
                .fill(accent.opacity(glowOpacity))
                .blur(radius: 40)
                .scaleEffect(circleScale * 1.25)
            
            // Main Orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.9), accent.opacity(0.5)],
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
                    // Glass highlight
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
                .scaleEffect(circleScale)
            
            VStack(spacing: 8) {
                Text(phaseTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)
                
                Text(guidanceText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.opacity)
            }
            .offset(y: -5)
        }
        .frame(width: 280, height: 280)
        .animation(.easeInOut(duration: phaseDuration), value: phase)
    }
    
    private var phaseTitle: String {
        if isComplete { return "Complete" }
        switch phase {
        case .inhale: return "Inhale"
        case .hold1, .hold2: return "Hold"
        case .exhale: return "Exhale"
        }
    }
    
    private var guidanceText: String {
        if isComplete { return "Well done!" }
        switch phase {
        case .inhale: return "Through your nose"
        case .hold1, .hold2: return "Hold gently"
        case .exhale: return "Slow exhale"
        }
    }
    
    private var phaseDuration: Double {
        switch phase {
        case .inhale, .exhale: return 4.0
        default: return 0.5
        }
    }
}
