import SwiftUI

struct DateStripHeaderView: View {
    @Binding var selectedDate: Date
    var firstWeekday: Int = 1
    var dateHasItems: (Date) -> Bool = { _ in false }

    @Namespace private var selectionAnimation

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private var allDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        // Wide range matching Chores interaction style for a "true" scrollable calendar strip
        return (-180...180).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header title is now handled by RootView, removing duplicate hierarchy
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(allDates, id: \.self) { date in
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            let isToday = calendar.isDateInToday(date)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                    proxy.scrollTo(calendar.startOfDay(for: date), anchor: .center)
                                }
                            } label: {
                                WeekStripDayView(
                                    date: date,
                                    isSelected: isSelected,
                                    isToday: isToday,
                                    hasItems: dateHasItems(date),
                                    namespace: selectionAnimation
                                )
                            }
                            .buttonStyle(.plain)
                            .id(calendar.startOfDay(for: date))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .center)
                }
                .onChange(of: selectedDate) { _, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(calendar.startOfDay(for: newValue), anchor: .center)
                    }
                }
            }
        }
    }
}

private struct WeekStripDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasItems: Bool
    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 10) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white.opacity(0.8) : Theme.secondaryText)

            ZStack {
                if isToday {
                    Circle()
                        .stroke(isSelected ? .white.opacity(0.4) : Theme.primaryPurple.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                if isSelected {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                }
            }
            .frame(height: 40)

            Circle()
                .fill(hasItems ? (isSelected ? .white : Theme.primaryPurple.opacity(0.6)) : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 54)
        .padding(.vertical, 14)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.primaryPurple)
                    .matchedGeometryEffect(id: "selectionPill", in: namespace)
            }
        }
    }
}

