import SwiftUI

struct EmptyStateView<Actions: View>: View {
    let title: String
    let systemImage: String
    let message: String
    let eyebrow: String?
    @ViewBuilder let actions: () -> Actions

    init(
        title: String,
        systemImage: String,
        message: String,
        eyebrow: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.eyebrow = eyebrow
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 8) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent)
                        .tracking(0.8)
                }

                Label(title, systemImage: systemImage)
            }
        } description: {
            Text(message)
        } actions: {
            actions()
        }
    }
}
