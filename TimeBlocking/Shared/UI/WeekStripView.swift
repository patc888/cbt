import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    let weekDates: [Date]
    var dateHasItems: (Date) -> Bool = { _ in false }
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                LazyHStack(spacing: 4) {
                    ForEach(weekDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let isToday = Calendar.current.isDateInToday(date)
                        let hasItems = dateHasItems(date)
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDate = date
                                proxy.scrollTo(date, anchor: .center)
                            }
                            HapticManager.shared.selection()
                        } label: {
                            WeekStripDayView(
                                date: date,
                                isSelected: isSelected,
                                isToday: isToday,
                                hasItems: hasItems,
                                namespace: animation
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .id(Calendar.current.startOfDay(for: date))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onAppear {
                    proxy.scrollTo(Calendar.current.startOfDay(for: selectedDate), anchor: .center)
                }
                .onChange(of: selectedDate) { _, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(Calendar.current.startOfDay(for: newValue), anchor: .center)
                    }
                }
            }
        }
    }
}

struct WeekStripDayView: View {
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
                    // Today ring (subtle pulse-like ring)
                    Circle()
                        .stroke(isSelected ? .white.opacity(0.4) : Theme.primaryAccent.opacity(0.3), lineWidth: 1.5)
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
            
            // Has Items Indicator
            Circle()
                .fill(hasItems ? (isSelected ? .white : Theme.primaryAccent.opacity(0.6)) : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 54)
        .padding(.vertical, 14)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.primaryAccent, Theme.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                    .matchedGeometryEffect(id: "selectionPill", in: namespace)
            }
        }

    }
}

