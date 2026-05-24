import SwiftUI

struct DistortionsEducationPage: View {
    @State private var selectedDistortion: String? = "All-of-Nothing"
    @Environment(ThemeManager.self) private var themeManager
    
    struct Distortion: Identifiable {
        let title: String
        let description: String
        var id: String { title }
    }
    
    let distortions = [
        Distortion(title: "All-or-Nothing", description: "Viewing things in black-and-white. 'If I'm not perfect, I failed.'"),
        Distortion(title: "Overgeneralization", description: "Seeing a single negative event as a never-ending pattern of defeat."),
        Distortion(title: "Mental Filter", description: "Picking out a single negative detail and dwelling on it exclusively."),
        Distortion(title: "Catastrophizing", description: "Assuming the worst possible outcome will happen, even with little evidence."),
        Distortion(title: "Mind Reading", description: "Assuming people are thinking negatively about you without proof.")
    ]
    
    private var selectedDescription: String? {
        distortions.first(where: { $0.title == selectedDistortion })?.description
    }
    
    var body: some View {
        PagerLayout(
            title: "Thinking Traps",
            subtitle: "We all fall into common patterns of distorted thinking. Recognizing them is half the battle."
        ) {
            VStack(spacing: 16) {
                ForEach(distortions) { item in
                    DistortionButton(
                        item: item,
                        isSelected: selectedDistortion == item.title,
                        themeColor: themeManager.selectedColor
                    ) {
                        withAnimation { selectedDistortion = item.title }
                    }
                }
                
                if let selected = selectedDistortion, let desc = selectedDescription {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(desc)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .id(selected)
                }
            }
        }
    }
}
