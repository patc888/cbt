import SwiftUI
import SwiftData

struct JournalSessionRow: View {
    let entry: JournalEntry
    let accent: Color

    private var sourceKind: SessionSourceKind? {
        guard let kind = entry.sourceKind else { return nil }
        return SessionSourceKind(rawValue: kind)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: sourceKind?.iconName ?? "book.pages")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(entry.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }

                HStack(spacing: 8) {
                    if let kind = sourceKind {
                        Text(kind.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(accent)
                    }
                    if let secs = entry.durationSeconds, secs > 0 {
                        Text(formattedDuration(secs))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 { return String(localized: "\(seconds)s") }
        let m = seconds / 60
        let r = seconds % 60
        return r > 0 ? String(localized: "\(m)m \(r)s") : String(localized: "\(m)m")
    }
}
