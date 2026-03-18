import SwiftUI

enum DSTypography {
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let sectionTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let sectionHeader = Font.system(size: 25, weight: .bold, design: .rounded)
    static let listLabel = Font.system(size: 16, weight: .medium, design: .rounded)
    static let cardTitle = Font.system(.caption, design: .rounded).weight(.heavy)
    static let metricValue = Font.system(.title2, design: .rounded).weight(.bold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded).weight(.medium)
    static let button = Font.system(.headline, design: .rounded)
}
