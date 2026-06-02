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
                    .lineLimit(2)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
        }
        .buttonStyle(DSSelectionButtonStyle(isSelected: isSelected, selectedColor: themeColor, size: .large))
    }
}
