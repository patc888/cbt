import SwiftUI

struct InsightsPatternSpotlightSection: View {
    let summary: InsightsPatternSummary

    @Environment(ThemeManager.self) private var themeManager

    private var cards: [PlainLanguagePatternInsight] {
        Array(summary.insightCards.prefix(4))
    }

    private var remainingCards: [PlainLanguagePatternInsight] {
        Array(cards.dropFirst())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Pattern Spotlight"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                if !cards.isEmpty {
                    Text(String(localized: "\(cards.count) SIGNALS"))
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.secondaryText.opacity(0.65))
                        .tracking(1.5)
                }
            }

            if cards.isEmpty {
                InsightsPatternEmptyCard()
            } else {
                InsightsFeaturedPatternCard(card: cards[0])

                if !remainingCards.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(remainingCards) { card in
                            InsightsPatternSignalCard(card: card)
                        }
                    }
                }
            }
        }
    }
}

private struct InsightsPatternEmptyCard: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            Text(String(localized: "Add a few mood check-ins with activities, emotions, triggers, and body cues to see patterns here."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct InsightsFeaturedPatternCard: View {
    let card: PlainLanguagePatternInsight

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryAccent: Color {
        Color(hex: themeManager.selectedTheme.secondaryHex)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }

                Image(systemName: card.iconName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(String(localized: "Featured Signal"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(card.title)
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.message)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemBackground))
                    #elseif canImport(AppKit)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color.black)
                    #endif
                    .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 14, x: 0, y: 8)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.selectedColor,
                                secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.9),
                                themeManager.selectedColor.opacity(colorScheme == .dark ? 0.7 : 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        ZStack {
                            InsightsPatternTexture()

                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct InsightsPatternSignalCard: View {
    let card: PlainLanguagePatternInsight

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: card.iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 34, height: 34)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct InsightsPatternTexture: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.16 : 0.1))
                        .frame(
                            width: proxy.size.width * CGFloat([0.18, 0.28, 0.14, 0.22, 0.1, 0.2, 0.16][index]),
                            height: CGFloat([4, 5, 4, 6, 4, 5, 4][index])
                        )
                        .rotationEffect(.degrees(-22))
                        .offset(
                            x: proxy.size.width * CGFloat([0.08, 0.56, 0.28, 0.78, 0.88, 0.42, 0.16][index]),
                            y: proxy.size.height * CGFloat([0.16, 0.12, 0.42, 0.36, 0.66, 0.78, 0.86][index])
                        )
                }

                LinearGradient(
                    colors: [.white.opacity(0.22), .white.opacity(0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
