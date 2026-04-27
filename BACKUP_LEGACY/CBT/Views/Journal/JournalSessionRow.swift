import SwiftUI
import SwiftData

struct JournalSessionRow: View {
    let entry: JournalEntry
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: entry.sessionSourceKind?.iconName ?? "book.pages")
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
                    if let kind = entry.sessionSourceKind {
                        Text(kind.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(accent)
                    }
                    if let durationLabel = entry.durationLabel {
                        Text(durationLabel)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
