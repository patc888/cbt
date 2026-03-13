import SwiftUI
import WidgetKit

@main
struct TimeBlockingWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextBlockWidget()
        TodaySummaryWidget()
    }
}
