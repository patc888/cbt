import OSLog
import Foundation

enum AppLogger {
    nonisolated static func make(category: String) -> Logger {
        Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "CBT",
            category: category
        )
    }
}
