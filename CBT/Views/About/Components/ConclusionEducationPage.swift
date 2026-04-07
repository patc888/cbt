import SwiftUI

struct ConclusionEducationPage: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "The Road Ahead",
            subtitle: "You now have the foundation. The next step is practice."
        ) {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.selectedColor)
                    .padding()
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to use this app:")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            BulletItem(icon: "face.smiling", text: "Check into your mood daily to see patterns.")
                            BulletItem(icon: "pencil.and.outline", text: "Fill out a Thought Record when you feel stressed.")
                            BulletItem(icon: "wind", text: "Use the Breathing Reset to calm your body.")
                            BulletItem(icon: "chart.line.uptrend.xyaxis", text: "Review your progress in Insights.")
                        }
                    }
                }
                
                Text("Consistency is more important than perfection. Take it one thought at a time.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 24)
            }
        }
    }
    
    struct BulletItem: View {
        let icon: String
        let text: String
        @Environment(ThemeManager.self) private var themeManager
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 24)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
