import SwiftUI

struct InsightsLoadingStateView: View {
    var body: some View {
        VStack {
            ProgressView()
                .padding()
            Text(String(localized: "Crunching your data..."))
                .foregroundStyle(Theme.secondaryText)
                .font(.subheadline)
        }
        .padding(.vertical, 40)
    }
}

struct InsightsEmptyStateView: View {
    @Binding var attemptingAddMood: Bool
    @Binding var attemptingAddThought: Bool
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeManager.selectedColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(themeManager.selectedColor)
                    
                    // Decorative sparkles
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.secondaryColor)
                        .offset(x: 35, y: -35)
                }
                .padding(.bottom, 8)

                Text(String(localized: "Unlock Your Insights"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(String(localized: "Complete mood check-ins and thought records to see your progress, trends, and breakthroughs over time."))
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }

            VStack(spacing: 16) {
                Button {
                    HapticManager.shared.lightImpact()
                    attemptingAddMood = true
                } label: {
                    HStack {
                        Image(systemName: "face.smiling")
                        Text(String(localized: "Log First Mood"))
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(themeManager.selectedColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.lightImpact()
                    attemptingAddThought = true
                } label: {
                    HStack {
                        Image(systemName: "brain")
                        Text(String(localized: "New Thought Record"))
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(themeManager.secondaryColor)
                    .background(themeManager.secondaryColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 48)
            .padding(.top, 16)

            Spacer()
        }
    }
}
