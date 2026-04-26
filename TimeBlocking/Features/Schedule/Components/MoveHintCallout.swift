import SwiftUI

struct MoveHintCallout: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Theme.primaryAccent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Move blocks directly")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("Use timeline drag to change time, or Move handle to change day.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Label("Timeline = time", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())

                Label("Move = day", systemImage: "calendar")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.primaryAccent.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.primaryAccent.opacity(0.14), lineWidth: 1)
        }
    }
}
