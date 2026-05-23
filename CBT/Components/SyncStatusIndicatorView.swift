import SwiftUI

struct SyncStatusIndicatorView: View {
    enum Style {
        case dot
        case label
    }

    @ObservedObject private var monitor: CloudSyncStatusMonitor
    private let style: Style

    init(
        monitor: CloudSyncStatusMonitor? = nil,
        style: Style = .label
    ) {
        self.monitor = monitor ?? .shared
        self.style = style
    }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: Date(), by: 60)) { _ in
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle()
                            .stroke(statusColor.opacity(0.28), lineWidth: 4)
                    }

                if style == .label {
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(monitor.accessibilityLabel)
        }
    }

    private var statusColor: Color {
        switch monitor.status {
        case .synced:
            return Theme.successGreen
        case .syncing:
            return .yellow
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch monitor.status {
        case .synced:
            return monitor.lastSyncDescription
        case .syncing:
            return "Syncing..."
        case .error:
            return "Sync error"
        }
    }
}
