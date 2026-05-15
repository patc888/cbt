import SwiftUI

struct EvidenceEducationPage: View {
    @State private var balance: CGFloat = -0.5 // -1 to 1
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        PagerLayout(
            title: "Evidence for & Against",
            subtitle: "Treat your thoughts like a scientist. Look for the actual facts, not just feelings."
        ) {
            VStack(spacing: 24) {
                // Interactive Balance Scale
                VStack(spacing: 12) {
                    ZStack {
                        // The Beam
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 8)
                            .rotationEffect(.degrees(Double(balance * 20)))
                        
                        // Pivot
                        TriangleIcon()
                            .fill(Theme.secondaryText.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .offset(y: 20)
                        
                        // Left Plate (Evidence FOR)
                        VStack {
                            Image(systemName: "hand.thumbsdown.fill")
                                .foregroundStyle(.red.opacity(0.6))
                            Text("FOR")
                                .font(.caption2.bold())
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                        .offset(x: -100, y: balance * 30)
                        
                        // Right Plate (Evidence AGAINST)
                        VStack {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundStyle(.green.opacity(0.6))
                            Text("AGAINST")
                                .font(.caption2.bold())
                                .foregroundStyle(.green.opacity(0.6))
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                        .offset(x: 100, y: -balance * 30)
                    }
                    .frame(height: 120)
                    .padding(.top, 20)
                    
                    Slider(value: $balance, in: -1...1)
                        .tint(themeManager.selectedColor)
                }
                
                DSCardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Weight of Evidence")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        
                        Text("Often, we give 'Negative Evidence' (feelings, past mistakes) too much weight. 'Positive Evidence' (facts, recent successes) is often ignored. CBT balances the scale.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ask yourself:")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    
                    BulletPoint(text: "Is there any other way to look at this?")
                    BulletPoint(text: "If a friend had this thought, what would I say?")
                    BulletPoint(text: "What facts support the opposite conclusion?")
                }
            }
        }
    }
    
    struct TriangleIcon: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

private struct BulletPoint: View {
    let text: String
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(themeManager.selectedColor)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
