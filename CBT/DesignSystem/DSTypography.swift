import SwiftUI

enum DSTypography {
    static let pageTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let sectionTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.caption, design: .rounded).weight(.heavy)
    static let metricValue = Font.system(.title2, design: .rounded).weight(.bold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
    static let button = Font.system(.headline, design: .rounded)
}
