import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    let weekDates: [Date]
    var dayHasActivity: (Date) -> Bool = { _ in false }
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                LazyHStack(spacing: 4) {
                    ForEach(weekDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let isToday = Calendar.current.isDateInToday(date)
                        let hasActivity = dayHasActivity(date)
                        
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
                                hasActivity: hasActivity,
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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasActivity: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 10) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
            ZStack {
                if isToday {
                    Circle()
                        .stroke(isSelected ? .white.opacity(0.4) : themeManager.selectedColor.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }

                if isSelected {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: 40)
            
            Circle()
                .fill(hasActivity ? (isSelected ? .white : themeManager.selectedColor.opacity(0.6)) : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 54)
        .padding(.vertical, 14)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [themeManager.selectedColor, themeManager.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryEffect(id: "selectionPill", in: namespace)
                    .shadow(color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 12, x: 0, y: 8)
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(themeManager.selectedColor.opacity(colorScheme == .dark ? 0.08 : 0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(
                                isToday ? themeManager.selectedColor.opacity(0.24) : Theme.secondaryText.opacity(0.08),
                                lineWidth: 1
                            )
                    }
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    let week = (-3...3).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    WeekStripView(selectedDate: $selectedDate, weekDates: week) { date in
        Calendar.current.component(.day, from: date) % 2 == 0
    }
    .padding()
    .background(Color.secondary.opacity(0.1))
}
