import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 64) {
                Spacer()
                
                // Animated Logo
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Theme.primaryAccent.opacity(0.15 - Double(index) * 0.04), lineWidth: 1)
                            .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                            .scaleEffect(isAnimating ? 1.1 : 0.8)
                            .opacity(isAnimating ? 0.3 : 0.6)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(Double(index) * 0.5), value: isAnimating)
                    }
                    
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .shadow(color: Theme.primaryAccent.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent.gradient)
                        .symbolEffect(.bounce, value: isAnimating)
                }
                
                VStack(spacing: 20) {
                    Text("TimeBlocking")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .opacity(textOpacity)
                    
                    Text("Design your day, find your focus.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .opacity(textOpacity)
                }
                
                // Premium Progress Bar
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.primaryText.opacity(0.05))
                            .frame(width: 240, height: 4)
                        
                        Capsule()
                            .fill(Theme.primaryAccent.gradient)
                            .frame(width: isAnimating ? 240 : 40, height: 4)
                            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    
                    Text("INITIALIZING ENVIRONMENT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                        .tracking(2)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
                textOpacity = 1.0
            }
        }
    }
}


#Preview {
    LoadingView()
}
