import SwiftUI

struct InsightsStreaksCard: View {
    let snapshot: InsightsDashboardSnapshot
    let timeRange: InsightsTimeRange
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    private var accent: Color {
        themeManager.selectedColor
    }

    private var secondaryAccent: Color {
        Color(hex: themeManager.selectedTheme.secondaryHex)
    }

    private var currentStreak: Int {
        snapshot.currentStreak
    }

    private var headline: String {
        if currentStreak > 0 {
            return currentStreak == 1
                ? String(localized: "1 day streak")
                : String(localized: "\(currentStreak) day streak")
        }

        if snapshot.activeDaysCount > 0 {
            return snapshot.activeDaysCount == 1
                ? String(localized: "1 active day")
                : String(localized: "\(snapshot.activeDaysCount) active days")
        }

        return String(localized: "Momentum is ready")
    }

    private var subheadline: String {
        if currentStreak > 0 {
            return String(localized: "You are building a stronger check-in rhythm.")
        }

        if snapshot.activeDaysCount > 0 {
            return String(localized: "You showed up \(snapshot.activeDaysCount) days in the last \(timeRange.days).")
        }

        return String(localized: "A mood check-in or thought record starts your insight trail.")
    }

    private var averageMoodText: String {
        snapshot.averageMood.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? String(localized: "-")
    }

    private var moodGoalText: String {
        "\(Int((snapshot.moodGoalProgress * 100).rounded()))%"
    }

    private var consistencyText: String {
        "\(Int((snapshot.consistencyProgress * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    heroIcon
                    heroCopy
                }

                VStack(alignment: .leading, spacing: 16) {
                    heroIcon
                    heroCopy
                }
            }

            InsightsHeroProgressTrack(
                progress: snapshot.consistencyProgress,
                label: String(localized: "\(snapshot.activeDaysCount)/\(snapshot.consistencyGoalTarget) active days"),
                value: consistencyText,
                animate: animate && !reduceMotion
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    heroPills
                }

                VStack(spacing: 10) {
                    heroPills
                }
            }
        }
        .padding(22)
        .background(heroBackground)
        .shadow(
            color: accent.opacity(colorScheme == .dark ? 0.32 : 0.2),
            radius: colorScheme == .dark ? 26 : 18,
            x: 0,
            y: colorScheme == .dark ? 18 : 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            guard !animate else { return }
            if reduceMotion {
                animate = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    animate = true
                }
            }
        }
    }

    private var heroIcon: some View {
        InsightsHeroMedallion(
            accent: accent,
            secondaryAccent: secondaryAccent,
            animate: animate && !reduceMotion
        )
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "\(snapshot.milestonesCompleted)/4 goals lit"), systemImage: "sparkle")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

            Text(headline)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .fixedSize(horizontal: false, vertical: true)

            Text(subheadline)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroPills: some View {
        InsightsHeroPill(
            icon: "chart.line.uptrend.xyaxis",
            title: String(localized: "Mood"),
            value: "\(averageMoodText)/10"
        )

        InsightsHeroPill(
            icon: "target",
            title: String(localized: "\(moodGoalValue)+"),
            value: moodGoalText
        )

        InsightsHeroPill(
            icon: "trophy.fill",
            title: String(localized: "Best"),
            value: "\(snapshot.longestStreak)d"
        )
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent,
                        secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.9),
                        accent.opacity(colorScheme == .dark ? 0.72 : 0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    InsightsHeroGlowPattern(animate: animate && !reduceMotion)

                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
            }
    }

    private var accessibilityLabel: String {
        String(
            localized: "Insights summary: \(headline). \(snapshot.activeDaysCount) active days in the last \(timeRange.days) days. Average mood \(averageMoodText) out of 10. Longest streak \(snapshot.longestStreak) days."
        )
    }
}

private struct InsightsHeroMedallion: View {
    let accent: Color
    let secondaryAccent: Color
    let animate: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 88, height: 88)
                .scaleEffect(pulse && animate ? 1.1 : 0.94)
                .opacity(pulse && animate ? 0.25 : 0.55)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 34, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, secondaryAccent.opacity(0.85))
                .shadow(color: .white.opacity(0.35), radius: 10, x: 0, y: 0)
                .scaleEffect(pulse && animate ? 1.05 : 0.98)
        }
        .frame(width: 88, height: 88)
        .onAppear {
            updatePulse(animate)
        }
        .onChange(of: animate) { _, newValue in
            updatePulse(newValue)
        }
    }

    private func updatePulse(_ shouldAnimate: Bool) {
        guard shouldAnimate else {
            pulse = false
            return
        }

        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct InsightsHeroGlowPattern: View {
    let animate: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.18 : 0.11))
                        .frame(
                            width: proxy.size.width * CGFloat([0.22, 0.13, 0.18, 0.28, 0.1, 0.2, 0.14, 0.24, 0.16][index]),
                            height: CGFloat([5, 4, 6, 5, 4, 5, 6, 4, 5][index])
                        )
                        .rotationEffect(.degrees(-22))
                        .offset(
                            x: proxy.size.width * CGFloat([0.02, 0.44, 0.7, 0.18, 0.84, 0.55, 0.08, 0.72, 0.36][index])
                                + (drift && animate ? CGFloat(index % 3) * 8 : 0),
                            y: proxy.size.height * CGFloat([0.2, 0.1, 0.24, 0.44, 0.52, 0.72, 0.78, 0.88, 0.62][index])
                        )
                        .opacity(animate && drift ? 1 : 0.52)
                }

                ForEach(0..<7, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "plus")
                        .font(.system(size: CGFloat([8, 10, 7, 9, 11, 8, 10][index]), weight: .bold))
                        .foregroundStyle(.white.opacity(index.isMultiple(of: 2) ? 0.28 : 0.18))
                        .offset(
                            x: proxy.size.width * CGFloat([0.18, 0.34, 0.62, 0.86, 0.24, 0.54, 0.76][index]),
                            y: proxy.size.height * CGFloat([0.16, 0.32, 0.12, 0.36, 0.72, 0.84, 0.64][index])
                        )
                        .scaleEffect(animate && drift ? 1.12 : 0.9)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            updateDrift(animate)
        }
        .onChange(of: animate) { _, newValue in
            updateDrift(newValue)
        }
    }

    private func updateDrift(_ shouldAnimate: Bool) {
        guard shouldAnimate else {
            drift = false
            return
        }

        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            drift = true
        }
    }
}

private struct InsightsHeroProgressTrack: View {
    let progress: Double
    let label: String
    let value: String
    let animate: Bool

    @State private var visibleProgress = 0.0

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.58)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * visibleProgress))
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .shadow(color: .white.opacity(0.45), radius: 8, x: 0, y: 0)
                                .padding(.trailing, 2)
                        }
                }
            }
            .frame(height: 12)

            HStack {
                Text(label)
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.76))
        }
        .onAppear {
            updateProgress(clampedProgress, animated: animate)
        }
        .onChange(of: clampedProgress) { _, newValue in
            updateProgress(newValue, animated: true)
        }
        .onChange(of: animate) { _, newValue in
            updateProgress(clampedProgress, animated: newValue)
        }
    }

    private func updateProgress(_ newValue: Double, animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.84).delay(0.12)) {
                visibleProgress = newValue
            }
        } else {
            visibleProgress = newValue
        }
    }
}

private struct InsightsHeroPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }
}
