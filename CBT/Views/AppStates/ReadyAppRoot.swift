import SwiftUI
import SwiftData
import os

struct ReadyAppRoot: View {
    private static let logger = AppLogger.make(category: "ReadyAppRoot")

    let container: ModelContainer
    let resetID: UUID
    let onAppear: () -> Void

    @EnvironmentObject private var securityManager: SecurityManager

    var body: some View {
        ContentView()
            .id(resetID)
            .onAppear {
                onAppear()
                logMainUIPresented()
                
                // Initialize sync monitor only after data layer is ready
                _ = CloudSyncMonitor.shared
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
