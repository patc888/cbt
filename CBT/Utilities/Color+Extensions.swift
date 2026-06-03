import SwiftUI

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#endif

extension Color {
    nonisolated init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    #if os(macOS) && !targetEnvironment(macCatalyst)
    init(resolvedNSColor nsColor: NSColor, appearance: NSAppearance? = NSApp?.effectiveAppearance) {
        let resolvedColor: NSColor
        if let appearance {
            resolvedColor = nsColor.resolvedColor(with: appearance)
        } else {
            resolvedColor = nsColor
        }

        if let concreteColor = resolvedColor.usingColorSpace(.sRGB)
            ?? resolvedColor.usingColorSpace(.deviceRGB) {
            self.init(
                .sRGB,
                red: concreteColor.redComponent,
                green: concreteColor.greenComponent,
                blue: concreteColor.blueComponent,
                opacity: concreteColor.alphaComponent
            )
            return
        }

        if let grayscaleColor = resolvedColor.usingColorSpace(.genericGray)
            ?? resolvedColor.usingColorSpace(.deviceGray) {
            self.init(
                .sRGB,
                red: grayscaleColor.whiteComponent,
                green: grayscaleColor.whiteComponent,
                blue: grayscaleColor.whiteComponent,
                opacity: grayscaleColor.alphaComponent
            )
            return
        }

        self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: resolvedColor.alphaComponent)
    }
    #endif
}
