import SwiftUI

struct MoodFABPicker: View {
    @Binding var isExpanded: Bool
    var onSelectMood: (MoodColor) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background dimming scrim
            if isExpanded {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
                    .transition(.opacity)
            }

            VStack(spacing: 12) {
                if isExpanded {
                    ForEach(MoodColor.allCases.reversed(), id: \.self) { mood in
                        MoodCircleButton(mood: mood) {
                            HapticManager.shared.trigger(.selection)
                            onSelectMood(mood)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .scale.combined(with: .opacity)
                                    .combined(with: .offset(y: 20)),
                                removal: .scale.combined(with: .opacity)
                                    .combined(with: .offset(y: 20))
                            )
                        )
                    }
                }

                // Main FAB
                Button {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.primaryColor)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: isExpanded ? "xmark" : "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 20)
            .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
        }
    }
}

private struct MoodCircleButton: View {
    let mood: MoodColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(mood.color)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                
                Text(mood.emoji)
                    .font(.system(size: 22))
            }
        }
        .buttonStyle(.plain)
    }
}
