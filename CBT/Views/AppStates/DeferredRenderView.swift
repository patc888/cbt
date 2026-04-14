import SwiftUI

struct DeferredRenderView<Placeholder: View, Content: View>: View {
    let isEnabled: Bool
    let delay: Duration?
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let content: () -> Content

    @State private var isReady = false

    init(
        isEnabled: Bool = true,
        delay: Duration? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEnabled = isEnabled
        self.delay = delay
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
        Group {
            if isReady {
                content()
            } else {
                placeholder()
            }
        }
        .task(id: isEnabled) {
            guard isEnabled, !isReady else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }

            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }

            await Task.yield()
            guard !Task.isCancelled else { return }
            isReady = true
        }
    }
}
