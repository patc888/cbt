import SwiftUI

struct TimelineRow: View {
    let item: TimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            iconView

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(2)
                    Spacer()
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(2)
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
    }

    private var iconName: String {
        switch item.kind {
        case .mood: return "face.smiling"
        case .thought: return "brain"
        case .exercise: return "figure.mind.and.body"
        case .journal: return "book.pages"
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .mood: return Theme.primaryColor
        case .thought: return .purple
        case .exercise: return .green
        case .journal: return .orange
        }
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
        }
    }
}
