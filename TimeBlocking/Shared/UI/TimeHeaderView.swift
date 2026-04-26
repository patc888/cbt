import SwiftUI

struct TimeHeaderView<Leading: View, Trailing: View>: View {
    @Binding var selectedDate: Date
    let weekStripDates: [Date]
    let dateHasItems: (Date) -> Bool
    let title: String
    let subtitle: String
    let horizontalPadding: CGFloat

    @ViewBuilder var leadingActions: Leading
    @ViewBuilder var trailingActions: Trailing

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                leadingActions
                    .frame(width: 44, alignment: .leading)
                
                Spacer()
                
                TopHeadlineView(
                    title: title,
                    subtitle: subtitle
                )
                
                Spacer()
                
                trailingActions
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, horizontalPadding)
            .fixedSize(horizontal: false, vertical: true)

            WeekStripView(
                selectedDate: $selectedDate,
                weekDates: weekStripDates,
                dateHasItems: dateHasItems
            )
            .frame(height: 90)
            .padding(.bottom, 4)
        }
    }
}

extension TimeHeaderView where Leading == EmptyView, Trailing == EmptyView {
    init(
        selectedDate: Binding<Date>,
        weekStripDates: [Date],
        dateHasItems: @escaping (Date) -> Bool,
        title: String,
        subtitle: String,
        horizontalPadding: CGFloat
    ) {
        self._selectedDate = selectedDate
        self.weekStripDates = weekStripDates
        self.dateHasItems = dateHasItems
        self.title = title
        self.subtitle = subtitle
        self.horizontalPadding = horizontalPadding
        self.leadingActions = EmptyView()
        self.trailingActions = EmptyView()
    }
}
