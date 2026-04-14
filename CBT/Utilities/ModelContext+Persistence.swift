import OSLog
import SwiftData

extension ModelContext {
    @MainActor
    @discardableResult
    func saveIfChanged(
        logger: Logger = AppLogger.make(category: "Persistence"),
        action: String
    ) -> Bool {
        guard hasChanges else { return true }

        do {
            try save()
            return true
        } catch {
            logger.error(
                "Failed to save context action=\(action, privacy: .public) error=\(error.localizedDescription, privacy: .private)"
            )
            return false
        }
    }
}
