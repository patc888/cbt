import SwiftUI

struct ScheduleFeedbackBannerState: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

struct ScheduleFeedbackBanner: View {
    let state: ScheduleFeedbackBannerState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: state.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(state.tint))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(state.message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(state.tint.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(state.tint.opacity(0.16), lineWidth: 1)
        }
    }
}

struct CalendarIntegrationBanner: View {
    let title: String
    let message: String
    var actionTitle: String?
    var isActionInProgress = false
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.blue)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
            }

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if isActionInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isActionInProgress ? "Requesting..." : actionTitle)
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.blue)
                    .controlSize(.small)
                    .disabled(isActionInProgress)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.16), lineWidth: 1)
        }
    }
}
