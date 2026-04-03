import Foundation

enum DurationFormatting {
    private static let componentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter
    }()

    static func sessionLabel(seconds: Int) -> String {
        guard seconds > 0 else { return String(localized: "0s") }
        if seconds < 60 { return String(localized: "\(seconds)s") }
        if seconds.isMultiple(of: 60) {
            return String(localized: "\(seconds / 60)m")
        }
        return componentsFormatter.string(from: TimeInterval(seconds)) ?? String(localized: "\(seconds)s")
    }
}
