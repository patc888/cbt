import SwiftUI

struct DayMoveRibbon: View {
    let targetDates: [Date]
    let selectedDate: Date
    let hoveredDate: Date?
    let coordinateSpaceName: String
    let detachNotice: Bool
    let preservedTimeText: String

    var body: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Label("Move Block", systemImage: "hand.draw.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Spacer(minLength: 0)

                    Text("Drop on a day")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.primaryGradient)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    StepBadge(number: "1", text: "Hold Move")
                    StepBadge(number: "2", text: "Hover Day")
                    StepBadge(number: "3", text: "Release")
                }

                Text(ribbonMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(targetDates, id: \.self) { date in
                            DayMoveTargetChip(
                                date: date,
                                isSelectedDay: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isHovered: hoveredDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                coordinateSpaceName: coordinateSpaceName
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.primaryAccent.opacity(0.04))
            )
        }
    }

    private var ribbonMessage: String {
        if let hoveredDate {
            let hoveredLabel = hoveredDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            let detachmentNote = detachNotice ? " It will become a manual block." : ""
            return "Release to move this block to \(hoveredLabel) at \(preservedTimeText).\(detachmentNote)"
        }

        if detachNotice {
            return "Drop on a nearby day to keep the \(preservedTimeText) start. Moving a generated block makes it manual."
        }

        return "Drop on a nearby day to keep the \(preservedTimeText) start and current duration."
    }
}

private struct StepBadge: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.primaryAccent))

            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.primaryAccent.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct DayMoveTargetChip: View {
    let date: Date
    let isSelectedDay: Bool
    let isHovered: Bool
    let coordinateSpaceName: String

    var body: some View {
        VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? .white.opacity(0.84) : Theme.secondaryText)

            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? .white : Theme.primaryText)

            Text(footerText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isHovered ? .white.opacity(0.84) : Theme.secondaryText)

            if isHovered {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 86)
        .padding(.vertical, 14)
        .background(backgroundShape)
        .overlay(alignment: .topTrailing) {
            if isSelectedDay {
                Circle()
                    .fill(isHovered ? Color.white.opacity(0.9) : Theme.primaryAccent)
                    .frame(width: 8, height: 8)
                    .padding(10)
            }
        }
        .scaleEffect(isHovered ? 1.06 : 1)
        .adaptiveShadow(
            color: isHovered ? Theme.primaryAccent.opacity(0.22) : .clear,
            radius: 14,
            x: 0,
            y: 10
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DayMoveTargetFramePreferenceKey.self,
                    value: [date: proxy.frame(in: .named(coordinateSpaceName))]
                )
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isHovered)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                isHovered
                    ? AnyShapeStyle(Theme.primaryGradient)
                    : AnyShapeStyle(Theme.primaryAccent.opacity(isSelectedDay ? 0.12 : 0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.22) : Theme.primaryAccent.opacity(isSelectedDay ? 0.18 : 0.1),
                        lineWidth: 1
                    )
            }
    }

    private var footerText: String {
        if isHovered {
            return "Drop Here"
        }

        if isSelectedDay {
            return "Current"
        }

        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        }

        return date.formatted(.dateTime.month(.abbreviated))
    }
}

struct DayMoveTargetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGRect] = [:]

    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue()) { _, next in next }
    }
}
