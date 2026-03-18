import SwiftUI

struct TimelineRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            iconView
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(2)
                    Spacer()
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(Theme.secondaryText)
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !item.chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.chips, id: \.self) { chip in
                                TagChip(title: chip)
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(describing: item.kind).capitalized) entry: \(item.title). \(item.subtitle ?? "")")
    }

    @ViewBuilder
    private var iconViewInner: some View {
        switch item.kind {
        case .mood:
            if case .mood(let entry) = item.route, let validColor = MoodColor(rawValue: entry.moodScore) {
                validColor.iconView
            } else {
                Image(systemName: "face.smiling")
            }
        case .thought: Image(systemName: "brain")
        case .exercise: Image(systemName: "figure.mind.and.body")
        case .journal: Image(systemName: "book.pages")
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .mood: return themeManager.selectedColor
        case .thought: return .purple
        case .exercise: return .green
        case .journal: return .orange
        }
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 48, height: 48)

            iconViewInner
                .font(.system(size: 24))
                .foregroundColor(iconColor)
        }
    }
}
