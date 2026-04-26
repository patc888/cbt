import SwiftUI

struct LockView: View {
    @ObservedObject private var securityManager = SecurityManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.primaryAccent)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated Lock Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animate ? 1.0 : 0.8)
                    
                    Image(systemName: !securityManager.isLocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                
                VStack(spacing: 12) {
                    Text("Time Blocking Locked")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Secure your schedule with Face ID\nor your passcode")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
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
                    .foregroundColor(Theme.primaryAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(.white)
                            .adaptiveShadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

#Preview {
    LockView()
}
