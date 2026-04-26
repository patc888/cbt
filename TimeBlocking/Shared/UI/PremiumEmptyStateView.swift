import SwiftUI

struct PremiumEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var eyebrow: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Background Glow
                Circle()
                    .fill(Theme.primaryAccent.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .scaleEffect(isAnimating ? 1.2 : 0.9)
                
                // Icon Container
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: systemImage)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.primaryAccent.gradient)
                        .symbolEffect(.bounce, value: isAnimating)
                }
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                if let eyebrow = eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent.opacity(0.8))
                        .tracking(2)
                }
                
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                
                Text(message)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primaryAccent.gradient)
                        .clipShape(Capsule())
                        .shadow(color: Theme.primaryAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground()
        PremiumEmptyStateView(
            title: "No Blocks Yet",
            message: "Your schedule for today is empty. Add a block to get started.",
            systemImage: "calendar.badge.plus",
            eyebrow: "GET STARTED",
            actionTitle: "Add Block",
            action: {}
        )
    }
}
