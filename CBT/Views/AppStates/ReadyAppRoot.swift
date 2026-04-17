import SwiftUI
import SwiftData
import os

struct ReadyAppRoot: View {
    private static let logger = AppLogger.make(category: "ReadyAppRoot")

    let container: ModelContainer
    let resetID: UUID
    let securityManager: SecurityManager
    let onAppear: () -> Void

    var body: some View {
        DeferredRenderView {
            ThemedBackground()
                .ignoresSafeArea()
                .overlay {
                    ProgressView()
                        .controlSize(.regular)
                }
        } content: {
            // Give the freshly attached SwiftData container one settled render
            // pass before the query-backed tab tree is constructed.
            ContentView()
                .id(resetID)
        }
        .onAppear {
            onAppear()
            logMainUIPresented()
        }
        .task(id: resetID) {
            // Start CloudKit monitoring only after the first launch frame has
            // settled so review launches do not mix query bootstrap with
            // account-status and event-observer work.
            await Task.yield()
            guard !Task.isCancelled else { return }

            await Task.yield()
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                CloudSyncMonitor.shared.startMonitoring()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: securityManager.isContentProtected)
        .modelContainer(container)
        .environmentObject(securityManager)
    }

    private func logMainUIPresented() {
        let platform: String
        #if targetEnvironment(macCatalyst)
        platform = "macCatalyst"
        #elseif canImport(UIKit)
        platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        platform = "macOS"
        #endif
        Self.logger.info(
            "Main UI presented – platform=\(platform, privacy: .public) resetID=\(resetID.uuidString.prefix(8), privacy: .public)"
        )
    }
}
