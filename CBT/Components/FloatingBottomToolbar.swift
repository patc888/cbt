import SwiftUI

enum FloatingTab: String, CaseIterable, Hashable {
    case home = "Home"
    case insights = "Insights"
    case assessments = "Assess"
    case exercises = "Exercises"
    case journal = "Journal"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home: return "house"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .assessments: return "checklist"
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
    @State private var attemptingNewMoodEntry: Bool = false
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

            ViewThatFits(in: .horizontal) {
                toolbarLayout(showsLabels: true, horizontalPadding: 16)
                toolbarLayout(showsLabels: false, horizontalPadding: 12)
            }
        }
        .sheet(isPresented: $showingMoodEntry, onDismiss: { selectedMood = nil }) {
            MoodCheckinView(initialMood: selectedMood)
        }
        .withUsageGate(isAttemptingAction: $attemptingNewMoodEntry) {
            showingMoodEntry = true
        }
    }

    private func toolbarLayout(showsLabels: Bool, horizontalPadding: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    tabButton(for: tab, showsLabel: showsLabels)
                }
            }
            .frame(minHeight: showsLabels ? 64 : 52)
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
                    .font(.system(size: showsLabel ? 16 : 17, weight: selectedTab == tab ? .bold : .semibold))
                    .environment(\.symbolVariants, selectedTab == tab ? .fill : .none)

                if showsLabel {
                    Text(tab.rawValue)
                        .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(selectedTab == tab ? themeManager.selectedColor : Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(minWidth: showsLabel ? 42 : 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
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

                            quickMoodIcon(for: mood, backgroundColor: moodColor)
                                .font(.system(size: 24, weight: .semibold))
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
    private func quickMoodIcon(for mood: MoodColor, backgroundColor: Color) -> some View {
        switch mood {
        case .veryLow:
            ToolbarFrownFaceIcon(isFilled: true, featureColor: backgroundColor)
                .frame(width: 24, height: 24)
        case .low:
            ToolbarFrownFaceIcon(isFilled: false, featureColor: .white)
                .frame(width: 24, height: 24)
        case .neutral, .good, .great:
            mood.iconView
        }
    }
}

private struct ToolbarFrownFaceIcon: View {
    let isFilled: Bool
    let featureColor: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.085, 1.6)

            ZStack {
                if isFilled {
                    Circle()
                        .fill(Color.white)
                    faceFeatures(size: size, color: featureColor, lineWidth: lineWidth)
                } else {
                    Circle()
                        .stroke(Color.white, lineWidth: lineWidth)
                    faceFeatures(size: size, color: .white, lineWidth: lineWidth)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func faceFeatures(size: CGFloat, color: Color, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size * 0.13, height: size * 0.13)
                .position(x: size * 0.37, y: size * 0.4)

            Circle()
                .fill(color)
                .frame(width: size * 0.13, height: size * 0.13)
                .position(x: size * 0.63, y: size * 0.4)

            FrownMouth()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.42, height: size * 0.2)
                .position(x: size * 0.5, y: size * 0.68)
        }
        .frame(width: size, height: size)
    }
}

private struct FrownMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}
