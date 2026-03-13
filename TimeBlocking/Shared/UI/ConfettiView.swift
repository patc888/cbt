import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let shape: ParticleShape
    let initialX: CGFloat
    let initialY: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let rotation: Double
    let rotationVelocity: Double
    let size: CGFloat
}

enum ParticleShape: CaseIterable {
    case circle, rectangle, sparkle
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animationProgress: CGFloat = 0
    let duration: Double = 0.8
    
    init() {
        // Particles will be generated in onAppear
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                ParticleView(particle: particle, progress: animationProgress)
            }
        }
        .onAppear {
            createParticles()
            withAnimation(.easeOut(duration: duration)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func createParticles() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan]
        var newParticles: [ConfettiParticle] = []
        
        for _ in 0..<80 {
            let angle = Double.random(in: 0..<Double.pi * 2)
            let speed = Double.random(in: 100..<350)
            
            newParticles.append(ConfettiParticle(
                color: colors.randomElement()!,
                shape: ParticleShape.allCases.randomElement()!,
                initialX: 0,
                initialY: 0,
                velocityX: CGFloat(cos(angle) * speed),
                velocityY: CGFloat(sin(angle) * speed),
                rotation: Double.random(in: 0..<360),
                rotationVelocity: Double.random(in: 360..<1080),
                size: CGFloat.random(in: 8..<18)
            ))
        }
        particles = newParticles
    }
}

struct ParticleView: View {
    let particle: ConfettiParticle
    let progress: CGFloat
    
    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle().fill(particle.color)
            case .rectangle:
                Rectangle().fill(particle.color)
            case .sparkle:
                Image(systemName: "sparkle").foregroundColor(particle.color)
            }
        }
        .frame(width: particle.size, height: particle.size)
        .rotationEffect(.degrees(particle.rotation + particle.rotationVelocity * Double(progress)))
        .offset(
            x: particle.velocityX * progress,
            y: (particle.velocityY * progress) + (200 * progress * progress) // Add gravity
        )
        .opacity(1.0 - Double(progress))
        .scaleEffect(1.0 - progress * 0.5)
    }
}
