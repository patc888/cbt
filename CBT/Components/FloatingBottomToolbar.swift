import SwiftUI

enum FloatingTab: String, CaseIterable, Hashable {
    case home = "Home"
    case insights = "Insights"
    case exercises = "Exercises"
    case journal = "Journal"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: return "house"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .exercises: return "figure.mind.and.body"
        case .journal: return "book.pages"
        case .settings: return "gearshape"
        }
    }
}

struct FloatingBottomToolbar: View {
    @Binding var selectedTab: FloatingTab

    @Environment(\.colorScheme) private var colorScheme

    private var visibleTabs: [FloatingTab] {
        FloatingTab.allCases
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Button {
                        guard selectedTab != tab else { return }
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .semibold))
                                .environment(\.symbolVariants, selectedTab == tab ? .fill : .none)

                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedTab == tab ? Theme.primaryColor : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 64)
            .background(Theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.isImmersive ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .cardShadow(colorScheme: colorScheme)

            Button {
                HapticManager.shared.mediumImpact()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.primaryColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: Theme.primaryColor.opacity(colorScheme == .dark ? 0.4 : 0), radius: colorScheme == .dark ? 10 : 0, x: 0, y: colorScheme == .dark ? 5 : 0)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
