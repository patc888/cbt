import SwiftUI

struct DistortionButton: View {
    let item: DistortionsEducationPage.Distortion
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(item.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(isSelected ? .white : Theme.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? AnyView(themeColor) : Theme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
