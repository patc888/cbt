import SwiftUI

struct LockView: View {
    @StateObject private var securityManager = SecurityManager.shared
    @Environment(ThemeManager.self) private var themeManager
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Using the themed primary color with a gradient for a premium look
            themeManager.primaryColor
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.2), .clear, .black.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Lock Icon with pulse effect
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(animate ? 1.1 : 0.9)
                        .opacity(animate ? 0.6 : 1.0)
                    
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 110, height: 110)
                        .scaleEffect(animate ? 1.0 : 0.85)
                    
                    Image(systemName: !securityManager.isLocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                
                VStack(spacing: 12) {
                    Text("App Locked")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Your CBT records are private.\nUnlock with Face ID or passcode.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.mediumImpact()
                    securityManager.authenticate()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 20, weight: .bold))
                        Text("Unlock App")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(themeManager.primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

#Preview {
    LockView()
        .environment(ThemeManager())
}
