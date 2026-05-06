import OSLog

@MainActor
final class ReviewManager {
    static let shared = ReviewManager()

    private let logger = AppLogger.make(category: "Review")

    private init() {}

    func logSignificantAction() {
        logger.debug("Review prompt disabled for stabilization build")
    }
}
