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

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded: Bool = false
    @State private var showingMoodEntry: Bool = false
    @State private var selectedMood: MoodColor? = nil

    private var visibleTabs: [FloatingTab] {
        FloatingTab.allCases
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if isExpanded {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if reduceMotion {
                            isExpanded = false
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                    }
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(visibleTabs, id: \.self) { tab in
                        Button {
                            guard selectedTab != tab else { return }
                            HapticManager.shared.selection()
                            if reduceMotion {
                                selectedTab = tab
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
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
                            .foregroundStyle(selectedTab == tab ? themeManager.selectedColor : Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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

                VStack(spacing: 12) {
                    if isExpanded {
                        ForEach(MoodColor.allCases.reversed(), id: \.self) { mood in
                            Button {
                                HapticManager.shared.selection()
                                selectedMood = mood
                                showingMoodEntry = true
                                if reduceMotion {
                                    isExpanded = false
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isExpanded = false
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(mood.color(with: themeManager.selectedColor))
                                        .frame(width: 48, height: 48)
                                        .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: mood.symbol)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(
                                reduceMotion ? .opacity :
                                .asymmetric(
                                    insertion: .scale.combined(with: .opacity)
                                        .combined(with: .offset(y: 20)),
                                    removal: .scale.combined(with: .opacity)
                                        .combined(with: .offset(y: 20))
                                )
                            )
                            .accessibilityLabel("\(mood.label) mood")
                        }
                    }

                    Button {
                        HapticManager.shared.mediumImpact()
                        if reduceMotion {
                            isExpanded.toggle()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.selectedColor)
                                .frame(width: 56, height: 56)
                                .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.4 : 0), radius: colorScheme == .dark ? 10 : 0, x: 0, y: colorScheme == .dark ? 5 : 0)

                            Image(systemName: isExpanded ? "xmark" : "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Close mood options" : "Quick Add Mood")
                    .accessibilityHint(isExpanded ? "Collapses the mood selection" : "Expands a list of moods to choose from")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingMoodEntry, onDismiss: { selectedMood = nil }) {
            MoodCheckinView(initialMood: selectedMood)
        }
    }
}
