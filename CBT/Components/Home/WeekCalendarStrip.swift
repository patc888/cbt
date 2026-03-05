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
                .padding(.top, 4)
                .padding(.bottom, 0)
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
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasActivity: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
            ZStack {
                if isSelected {
                    // Outer Ring / Halo
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Inner Circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0), radius: colorScheme == .dark ? 2 : 0, x: 0, y: colorScheme == .dark ? 1 : 0)
                    
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryColor)
                } else {
                    if isToday {
                        // Today ring (subtle pulse-like ring)
                        Circle()
                            .stroke(Theme.primaryColor.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 36, height: 36)
                    }
                    
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: 40)
            
            // Has Activity Indicator
            Circle()
                .fill(hasActivity ? (isSelected ? .white : Theme.primaryColor.opacity(0.6)) : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 54)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.primaryGradient)
                    .matchedGeometryEffect(id: "selectionPill", in: namespace)
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    let week = (-3...3).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    return WeekStripView(selectedDate: $selectedDate, weekDates: week) { date in
        Calendar.current.component(.day, from: date) % 2 == 0
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
