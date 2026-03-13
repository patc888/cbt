import Foundation

enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable {
    case dashboard
    case schedule
    case templates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .schedule:
            "Schedule"
        case .templates:
            "Templates"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "chart.bar.xaxis"
        case .schedule:
            "calendar.day.timeline.leading"
        case .templates:
            "square.on.square"
        }
    }
}
