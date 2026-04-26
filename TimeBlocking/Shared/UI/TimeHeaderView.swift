import SwiftUI

struct TimeHeaderView: View {
    @Binding var selectedDate: Date
    let weekStripDates: [Date]
    let calendar: Calendar
    let horizontalPadding: CGFloat

    // Callback for dot indicator in week strip
    var dateHasItems: (Date) -> Bool

    var showHeadline: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            if showHeadline {
                TopHeadlineView(
                    title: titleForSelectedDate,
                    subtitle: subtitleForSelectedDate
                )
                .padding(.horizontal, horizontalPadding)
            }

            WeekStripView(
                selectedDate: $selectedDate,
                weekDates: weekStripDates,
                dateHasItems: dateHasItems
            )
            .padding(.top, 4)
            .padding(.horizontal, horizontalPadding)
        }
    }

    private var titleForSelectedDate: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.wide))
        }
    }

    private var subtitleForSelectedDate: String {
        selectedDate.formatted(.dateTime.month(.wide).day())
    }
}
