import SwiftUI

struct CalendarEventRow: View {
    let event: TimeCalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)

                    Text(timeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)

                Text("Read only")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Label(event.sourceTitle, systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.blue)

                if let location = event.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
        }
    }

    private var timeText: String {
        if event.isAllDay {
            return "All day"
        }

        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

struct TimeBlockDragPreviewView: View {
    let block: TimeBlock
    let destinationDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: categorySymbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tintColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    Text(timeRangeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if let destinationDate {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.primaryAccent)

                    Text("Moving to \(destinationDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.primaryAccent.opacity(0.2), lineWidth: 1)
        }
        .frame(width: 280)
    }

    private var categorySymbol: String {
        switch block.category {
        case .focus: return "scope"
        case .personal: return "figure.walk"
        case .admin: return "tray.full.fill"
        case .routine: return "repeat"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    private var tintColor: Color {
        switch block.category {
        case .focus: return Theme.primaryAccent
        case .personal: return Color(hex: "F59E0B")
        case .admin: return Color(hex: "0EA5E9")
        case .routine: return Color(hex: "10B981")
        case .custom: return Color(hex: "64748B")
        }
    }

    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

struct DayTimelineEmptyState: View {
    let date: Date
    let onPlan: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Theme.primaryAccent.opacity(0.12))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Theme.primaryAccent.opacity(0.05))
                    .frame(width: 130, height: 130)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Theme.primaryAccent.gradient)
                    .symbolEffect(.bounce, options: .repeating)
            }
            .padding(.top, 10)

            VStack(spacing: 12) {
                Text(String(localized: "Fresh Slate"))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(String(localized: "No blocks scheduled for \(date.formatted(date: .abbreviated, time: .omitted)). Start designing your day now."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }

            Button(action: {
                HapticManager.shared.lightImpact()
                onPlan()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(String(localized: "Plan Your Day"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Theme.primaryAccent.gradient)
                .clipShape(Capsule())
                .shadow(color: Theme.primaryAccent.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Theme.primaryAccent.opacity(0.1), lineWidth: 1)
                }
        )
    }
}
