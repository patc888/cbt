import SwiftUI

struct MoodIntensitySelector: View {
    @Binding var intensity: Double
    let selectedColor: MoodColor?
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("How strong is this feeling?")
                .font(DSTypography.pageTitle)
                .foregroundStyle(DSTheme.primaryText)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 24) {
                Text("\(Int(intensity))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(selectedColor?.color ?? Theme.primaryColor)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: intensity)
                
                Slider(value: $intensity, in: 1...10, step: 1) {
                    Text("Intensity")
                } minimumValueLabel: {
                    Text("1").font(.caption).foregroundStyle(Theme.secondaryText)
                } maximumValueLabel: {
                    Text("10").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .tint(selectedColor?.color ?? Theme.primaryColor)
                .padding(.horizontal, 32)
            }
            
            Spacer()
            
            Button("Continue") {
                onNext()
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding(.horizontal, DSSpacing.large)
            .padding(.bottom, DSSpacing.large)
        }
    }
}
