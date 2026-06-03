import SwiftUI

enum FloatingTab: String, CaseIterable, Hashable {
    case home = "Today"
    case plan = "Plan"
    case insights = "Insights"
    case assessments = "Assess"
    case toolkit = "Toolkit"
    case exercises = "Tools"
    case journal = "Journal"
    case settings = "Settings"
    case profile = "Profile"

    var displayTitle: String {
        switch self {
        case .home: return "Today"
        case .plan: return "Plan"
        case .insights: return "Insights"
        case .assessments: return "Assessments"
        case .toolkit: return "Toolkit"
        case .exercises: return "Tools"
        case .journal: return "Journal"
        case .settings: return "Settings"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .plan: return "point.topleft.down.curvedto.point.bottomright.up"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .assessments: return "checklist"
        case .toolkit: return "lifepreserver"
        case .exercises: return "square.grid.2x2"
        case .journal: return "book.pages"
        case .settings: return "gearshape"
        case .profile: return "person.crop.circle"
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
    @State private var attemptingNewMoodEntry: Bool = false
    @State private var selectedMood: MoodColor? = nil

    private var visibleTabs: [FloatingTab] {
        [.home, .plan, .exercises, .journal, .insights, .settings]
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

            ViewThatFits(in: .horizontal) {
                toolbarLayout(showsLabels: true, horizontalPadding: 16)
                toolbarLayout(showsLabels: false, horizontalPadding: 12)
            }
        }
        .sheet(isPresented: $showingMoodEntry, onDismiss: { selectedMood = nil }) {
            MoodCheckinView(initialMood: selectedMood)
                .dsSheetPresentation()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewMoodEntry) {
            showingMoodEntry = true
        }
    }

    private func toolbarLayout(showsLabels: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: showsLabels ? 2 : 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    tabButton(for: tab, showsLabel: showsLabels)
                }
            }
            .padding(.horizontal, showsLabels ? 8 : 6)
            .frame(minHeight: showsLabels ? 62 : 52)
            .background(Theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.isImmersive ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .cardShadow(colorScheme: colorScheme)
            .offset(y: DSSpacing.xSmall)

            quickMoodButtonStack
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 8)
    }

    private func tabButton(for tab: FloatingTab, showsLabel: Bool) -> some View {
        Button {
            guard selectedTab != tab else { return }
            HapticManager.shared.selection()
            if reduceMotion {
                isExpanded = false
                selectedTab = tab
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: showsLabel ? 4 : 0) {
                Image(systemName: tab.icon)
                    .font(.system(size: showsLabel ? 16 : 18, weight: selectedTab == tab ? .bold : .semibold))
                    .environment(\.symbolVariants, selectedTab == tab ? .fill : .none)

                if showsLabel {
                    Text(tab.displayTitle)
                        .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(selectedTab == tab ? themeManager.selectedColor : Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(minWidth: showsLabel ? 44 : 32, minHeight: showsLabel ? 48 : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.displayTitle)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    private var quickMoodButtonStack: some View {
        VStack(spacing: 12) {
            if isExpanded {
                ForEach(MoodColor.allCases, id: \.self) { mood in
                    Button {
                        HapticManager.shared.selection()
                        selectedMood = mood
                        attemptingNewMoodEntry = true
                        if reduceMotion {
                            isExpanded = false
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                    } label: {
                        let moodColor = mood.color(with: themeManager.selectedColor)

                        ZStack {
                            Circle()
                                .fill(moodColor)
                                .frame(width: 56, height: 56)
                                .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 4, x: 0, y: 2)

                            quickMoodIcon(for: mood)
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

    @ViewBuilder
    private func quickMoodIcon(for mood: MoodColor) -> some View {
        mood.icon(size: 24)
    }
}
