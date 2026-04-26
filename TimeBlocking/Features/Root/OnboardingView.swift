import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    let onComplete: () -> Void
    
    private let steps = [
        OnboardingStep(
            title: "Design Your Day",
            description: "Break your day into focused blocks of time. Master your schedule, don't let it master you.",
            image: "calendar.badge.clock",
            color: Theme.primaryAccent
        ),
        OnboardingStep(
            title: "Routines & Flow",
            description: "Create recurring templates for your best days. Regenerate your perfect routine with a single tap.",
            image: "repeat",
            color: Theme.secondaryAccent
        ),
        OnboardingStep(
            title: "Insights & Growth",
            description: "Track your consistency and see your progress. Turn abstract goals into measurable achievements.",
            image: "chart.bar.fill",
            color: Theme.successGreen
        ),
        OnboardingStep(
            title: "Ready to Focus?",
            description: "Join thousands who use time blocking to reclaim their focus and reach their peak potential.",
            image: "sparkles",
            color: Theme.warningOrange
        )
    ]
    
    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        complete()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                }
                .padding()
                
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        VStack(spacing: 40) {
                            Spacer()
                            
                            // Animated Icon
                            ZStack {
                                Circle()
                                    .fill(steps[index].color.opacity(0.1))
                                    .frame(width: 200, height: 200)
                                    .scaleEffect(currentStep == index ? 1 : 0.5)
                                    .opacity(currentStep == index ? 1 : 0)
                                
                                Image(systemName: steps[index].image)
                                    .font(.system(size: 80))
                                    .foregroundStyle(steps[index].color.gradient)
                                    .symbolEffect(.bounce, value: currentStep == index)
                            }
                            
                            VStack(spacing: 16) {
                                Text(steps[index].title)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .multilineTextAlignment(.center)
                                
                                Text(steps[index].description)
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .lineSpacing(4)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom Indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(currentStep == index ? steps[index].color : Theme.secondaryText.opacity(0.2))
                            .frame(width: currentStep == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.bottom, 40)
                
                // Action Button
                Button {
                    if currentStep < steps.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                        HapticManager.shared.lightImpact()
                    } else {
                        complete()
                    }
                } label: {
                    Text(currentStep == steps.count - 1 ? "Start Your Journey" : "Continue")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(steps[currentStep].color.gradient)
                        }
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    private func complete() {
        HapticManager.shared.mediumImpact()
        withAnimation(.smooth(duration: 0.6)) {
            onComplete()
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let image: String
    let color: Color
}

#Preview {
    OnboardingView(onComplete: {})
}
