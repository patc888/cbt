import SwiftUI

struct AffirmationCardView: View {
    let affirmation: Affirmation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    
    // Create a consistent slight random rotation based on ID for a "stack of cards" feel
    private var rotationAngle: Double {
        let hash = abs(affirmation.id.hashValue) % 6
        return Double(hash) - 2.5 // -2.5 to +2.5 degrees
    }
    
    var body: some View {
        ZStack {
            // Opaque Base Layer
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(
                    color: (themeManager?.selectedColor ?? .accentColor).opacity(colorScheme == .dark ? 0.2 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            
            // Fancy Gradient Overlay
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (themeManager?.selectedColor ?? .accentColor).opacity(colorScheme == .dark ? 0.3 : 0.15),
                            (themeManager?.selectedColor ?? .accentColor).opacity(colorScheme == .dark ? 0.1 : 0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle Border
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            (themeManager?.selectedColor ?? .accentColor).opacity(0.6),
                            Color.clear,
                            (themeManager?.selectedColor ?? .accentColor).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            // Content
            VStack(spacing: 0) {
                // Category Pill
                Text(affirmation.category.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(themeManager?.selectedColor ?? .accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill((themeManager?.selectedColor ?? .accentColor).opacity(0.15))
                    )
                    .padding(.top, 24)
                
                Spacer()
                
                Image(systemName: "quote.opening")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle((themeManager?.selectedColor ?? .accentColor).opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                    .offset(y: 20)
                
                Text(affirmation.text)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DSTheme.primaryText)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
                
                Image(systemName: "quote.closing")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle((themeManager?.selectedColor ?? .accentColor).opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 24)
                    .offset(y: -20)
                
                Spacer()
                Spacer().frame(height: 24)
            }
        }
        .rotationEffect(.degrees(rotationAngle))
        .padding(.horizontal, DSSpacing.xLarge)
        .padding(.vertical, DSSpacing.large)
    }
}
