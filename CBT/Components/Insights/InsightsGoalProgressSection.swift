import SwiftUI

struct InsightsGoalProgressSection: View {
    let snapshot: InsightsDashboardSnapshot
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager
    @State private var revealProgress = false

    private var goalItems: [InsightsGoalProgressItem] {
        [
            InsightsGoalProgressItem(
                id: "consistency",
                title: String(localized: "Consistency Goal"),
                subtitle: String(localized: "\(snapshot.activeDaysCount) of \(snapshot.consistencyGoalTarget) active days"),
                icon: "calendar.badge.checkmark",
                progress: snapshot.consistencyProgress,
                tint: themeManager.selectedColor
            ),
            InsightsGoalProgressItem(
                id: "mood",
                title: String(localized: "Mood Goal (\(moodGoalValue)+)"),
                subtitle: String(localized: "\(Int((snapshot.moodGoalProgress * 100).rounded()))% entries hit target"),
                icon: "heart.text.square.fill",
                progress: snapshot.moodGoalProgress,
                tint: themeManager.secondaryColor
            ),
            InsightsGoalProgressItem(
                id: "thought-relief",
                title: String(localized: "Thought Relief Goal"),
                subtitle: snapshot.averageIntensityImprovement.map {
                    String(localized: "\($0) of 15 pts average relief")
                } ?? String(localized: "Thought relief appears after a thought record."),
                icon: "brain.head.profile",
                progress: snapshot.thoughtGoalProgress,
                tint: .orange
            ),
            InsightsGoalProgressItem(
                id: "exercise",
                title: String(localized: "Exercise Goal"),
                subtitle: String(localized: "\(completedExerciseCount) of \(snapshot.exerciseGoalTarget) exercises"),
                icon: "figure.mind.and.body",
                progress: snapshot.exerciseProgress,
                tint: .green
            )
        ]
    }

    private var completedExerciseCount: Int {
        let rawCount = Int((snapshot.exerciseProgress * Double(snapshot.exerciseGoalTarget)).rounded())
        return min(snapshot.exerciseGoalTarget, max(0, rawCount))
    }

    private var completedGoalCount: Int {
        goalItems.filter { $0.clampedProgress >= 1 }.count
    }

    private var averageGoalProgress: Double {
        guard !goalItems.isEmpty else { return 0 }
        let total = goalItems.reduce(0) { $0 + $1.clampedProgress }
        return total / Double(goalItems.count)
    }

    private var strongestGoal: InsightsGoalProgressItem? {
        goalItems.max { $0.clampedProgress < $1.clampedProgress }
    }

    private var summaryHeadline: String {
        if completedGoalCount == goalItems.count {
            return String(localized: "Every goal is complete")
        }

        if averageGoalProgress >= 0.7 {
            return String(localized: "Momentum is taking shape")
        }

        if averageGoalProgress >= 0.35 {
            return String(localized: "Steady progress is building")
        }

        return String(localized: "A fresh stretch is ready")
    }

    private var summaryDetail: String {
        if let strongestGoal, strongestGoal.clampedProgress > 0 {
            return String(localized: "\(strongestGoal.title) is leading the board at \(strongestGoal.percentText).")
        }

        return String(localized: "Start with one check-in, thought record, or exercise to light up the board.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Goal Progress"))
                        .font(DSTypography.sectionTitle)
                        .foregroundStyle(Theme.primaryText)

                    Text(String(localized: "Consistency, mood, relief, and practice"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Label("\(completedGoalCount)/\(goalItems.count)", systemImage: "target")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(themeManager.selectedColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(themeManager.selectedColor.opacity(0.12), in: Capsule())
                    .accessibilityLabel(String(localized: "\(completedGoalCount) of \(goalItems.count) goals complete"))
            }

            InsightsGoalProgressSummaryCard(
                progress: averageGoalProgress,
                completedCount: completedGoalCount,
                totalCount: goalItems.count,
                headline: summaryHeadline,
                detail: summaryDetail,
                accent: themeManager.selectedColor,
                secondaryAccent: themeManager.secondaryColor,
                animate: revealProgress
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(goalItems) { item in
                    InsightsGoalProgressCard(item: item, animate: revealProgress)
                }
            }
        }
        .onAppear {
            revealProgress = true
        }
    }
}

private struct InsightsGoalProgressItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let progress: Double
    let tint: Color

    var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var percentText: String {
        "\(Int((clampedProgress * 100).rounded()))%"
    }

    var status: InsightsGoalProgressStatus {
        if clampedProgress >= 1 {
            return .complete
        }

        if clampedProgress >= 0.7 {
            return .onTrack
        }

        if clampedProgress > 0 {
            return .building
        }

        return .ready
    }
}

private enum InsightsGoalProgressStatus {
    case complete
    case onTrack
    case building
    case ready

    var title: String {
        switch self {
        case .complete:
            return String(localized: "Complete")
        case .onTrack:
            return String(localized: "On Track")
        case .building:
            return String(localized: "Building")
        case .ready:
            return String(localized: "Ready")
        }
    }

    var detail: String {
        switch self {
        case .complete:
            return String(localized: "Goal met")
        case .onTrack:
            return String(localized: "Close to target")
        case .building:
            return String(localized: "In motion")
        case .ready:
            return String(localized: "Ready when you are")
        }
    }

    var icon: String {
        switch self {
        case .complete:
            return "checkmark.seal.fill"
        case .onTrack:
            return "arrow.up.right.circle.fill"
        case .building:
            return "sparkle"
        case .ready:
            return "circle.dashed"
        }
    }
}

private struct InsightsGoalProgressSummaryCard: View {
    let progress: Double
    let completedCount: Int
    let totalCount: Int
    let headline: String
    let detail: String
    let accent: Color
    let secondaryAccent: Color
    let animate: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var visibleProgress = 0.0

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var percentText: String {
        "\(Int((visibleProgress * 100).rounded()))%"
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                progressRing
                summaryCopy
            }

            VStack(alignment: .leading, spacing: 18) {
                progressRing
                summaryCopy
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemBackground))
                    #elseif canImport(AppKit)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color.black)
                    #endif
                    .shadow(
                        color: accent.opacity(colorScheme == .dark ? 0.28 : 0.16),
                        radius: colorScheme == .dark ? 24 : 16,
                        x: 0,
                        y: colorScheme == .dark ? 14 : 8
                    )

                summaryBackground
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Goal progress summary. \(completedCount) of \(totalCount) goals complete. \(headline). \(detail)"))
        .accessibilityValue(String(localized: "\(Int((clampedProgress * 100).rounded())) percent complete"))
        .onAppear {
            updateProgress(clampedProgress, animated: animate && !reduceMotion)
        }
        .onChange(of: clampedProgress) { _, newValue in
            updateProgress(newValue, animated: animate && !reduceMotion)
        }
        .onChange(of: animate) { _, newValue in
            if newValue || reduceMotion {
                updateProgress(clampedProgress, animated: newValue && !reduceMotion)
            }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 12)

            Circle()
                .trim(from: 0, to: visibleProgress <= 0 ? 0 : max(0.001, visibleProgress))
                .stroke(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(percentText)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(String(localized: "OVERALL"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.1)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 112, height: 112)
        .accessibilityHidden(true)
    }

    private var summaryCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                String(localized: "\(completedCount)/\(totalCount) goals complete"),
                systemImage: completedCount == totalCount ? "checkmark.seal.fill" : "flag.checkered"
            )
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.15), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }

            Text(headline)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent,
                        secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.88),
                        accent.opacity(colorScheme == .dark ? 0.78 : 0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    InsightsGoalProgressTexture()

                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
            }
    }

    private func updateProgress(_ newValue: Double, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.84)) {
                visibleProgress = newValue
            }
        } else {
            visibleProgress = newValue
        }
    }
}

private struct InsightsGoalProgressTexture: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.18 : 0.1))
                        .frame(
                            width: proxy.size.width * CGFloat([0.16, 0.28, 0.12, 0.22, 0.18, 0.25, 0.14, 0.2, 0.1, 0.24][index]),
                            height: CGFloat([5, 4, 5, 6, 4, 5, 6, 4, 5, 5][index])
                        )
                        .rotationEffect(.degrees(-24))
                        .offset(
                            x: proxy.size.width * CGFloat([0.04, 0.3, 0.62, 0.78, 0.18, 0.54, 0.86, 0.08, 0.42, 0.68][index]),
                            y: proxy.size.height * CGFloat([0.18, 0.1, 0.24, 0.4, 0.5, 0.66, 0.56, 0.82, 0.88, 0.72][index])
                        )
                }

                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "plus")
                        .font(.system(size: CGFloat([8, 10, 7, 9, 11, 8][index]), weight: .bold))
                        .foregroundStyle(.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.17))
                        .offset(
                            x: proxy.size.width * CGFloat([0.2, 0.38, 0.66, 0.9, 0.3, 0.72][index]),
                            y: proxy.size.height * CGFloat([0.16, 0.36, 0.14, 0.32, 0.78, 0.86][index])
                        )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct InsightsGoalProgressCard: View {
    let item: InsightsGoalProgressItem
    let animate: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var visibleProgress = 0.0

    private var status: InsightsGoalProgressStatus {
        item.status
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    leadingContent
                    Spacer(minLength: 8)
                    progressValue
                }

                VStack(alignment: .leading, spacing: 12) {
                    leadingContent
                    progressValue
                }
            }

            progressTrack

            HStack(alignment: .center, spacing: 10) {
                Label(status.detail, systemImage: status.icon)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(item.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                milestoneSegments
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardBackground
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title): \(item.subtitle). \(status.title).")
        .accessibilityValue("\(item.percentText) complete")
        .onAppear {
            if reduceMotion || animate {
                updateProgress(item.clampedProgress, animated: animate && !reduceMotion)
            }
        }
        .onChange(of: item.clampedProgress) { _, newValue in
            updateProgress(newValue, animated: animate && !reduceMotion)
        }
        .onChange(of: animate) { _, newValue in
            if newValue || reduceMotion {
                updateProgress(item.clampedProgress, animated: newValue && !reduceMotion)
            }
        }
    }

    private var leadingContent: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(item.tint.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(item.tint.opacity(0.24), lineWidth: 1)
                    }

                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.tint)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progressValue: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(Int((visibleProgress * 100).rounded()))%")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(item.tint)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(status.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(item.tint)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(item.tint.opacity(0.12), in: Capsule())
        }
        .frame(minWidth: 74, alignment: .trailing)
    }

    private var progressTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.trackBackgroundColor(for: colorScheme))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [item.tint, item.tint.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: visibleProgress <= 0 ? 0 : max(8, proxy.size.width * CGFloat(visibleProgress)))
                    .overlay(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(colorScheme == .dark ? 0.92 : 0.82))
                            .frame(width: 4, height: 14)
                            .padding(.trailing, 5)
                            .opacity(visibleProgress > 0 ? 1 : 0)
                    }
            }
        }
        .frame(height: 12)
    }

    private var milestoneSegments: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(visibleProgress >= Double(index) / 4.0 ? item.tint : Theme.trackBackgroundColor(for: colorScheme))
                    .frame(width: 18, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(DSTheme.cardBackground)
            .overlay {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            item.tint.opacity(colorScheme == .dark ? 0.18 : 0.11),
                            item.tint.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(item.tint.opacity(colorScheme == .dark ? 0.12 : 0.08))
                            .frame(width: CGFloat([52, 34, 44, 26, 38][index]), height: 4)
                            .rotationEffect(.degrees(-22))
                            .offset(
                                x: CGFloat([18, 72, 136, 214, 262][index]),
                                y: CGFloat([16, 42, 20, 64, 30][index])
                            )
                    }

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(item.tint.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
                }
            }
            .shadow(
                color: item.tint.opacity(colorScheme == .dark ? 0.16 : 0.08),
                radius: colorScheme == .dark ? 14 : 10,
                x: 0,
                y: colorScheme == .dark ? 8 : 5
            )
    }

    private func updateProgress(_ newValue: Double, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.78, dampingFraction: 0.86)) {
                visibleProgress = newValue
            }
        } else {
            visibleProgress = newValue
        }
    }
}
