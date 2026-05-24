import SwiftUI

#if os(macOS)
import AppKit
#endif

enum MoodColor: Int, CaseIterable {
    case veryLow = 1
    case low = 2
    case neutral = 3
    case good = 4
    case great = 5
    
    func color(with themeColor: Color) -> Color {
        switch self {
        case .veryLow:
            #if os(macOS) || targetEnvironment(macCatalyst)
            // macOS can make low-opacity monochrome SF Symbols look "blank".
            return themeColor.opacity(0.55)
            #else
            return themeColor.opacity(0.3)
            #endif
        case .low:
            #if os(macOS) || targetEnvironment(macCatalyst)
            return themeColor.opacity(0.65)
            #else
            return themeColor.opacity(0.45)
            #endif
        case .neutral: return themeColor.opacity(0.6)
        case .good: return themeColor.opacity(0.8)
        case .great: return themeColor
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        ZStack {
            switch self {
            case .veryLow:
                MoodColor.frownIcon(isFilled: true)
            case .low:
                MoodColor.frownIcon(isFilled: false)
            case .neutral:
                Image(systemName: "face.smiling")
            case .good:
                Image(systemName: "face.smiling")
            case .great:
                Image(systemName: "face.smiling.fill")
            }
        }
    }

    @ViewBuilder
    private static func frownIcon(isFilled: Bool) -> some View {
        if let symbolName = MoodColor.frownSymbolName(isFilled: isFilled) {
            Image(systemName: symbolName)
        } else {
            Text("\u{2639}\u{FE0E}")
                .fontWeight(isFilled ? .black : .semibold)
        }
    }

    private static func frownSymbolName(isFilled: Bool) -> String? {
        // SF Symbols face variants differ across OS versions / SF Symbols packs.
        // Fall back to a text frown instead of a blank or smiling icon.
        let outlineCandidates: [String] = [
            "face.sad",
            "face.frowning",
            "face.frown",
        ]

        let filledCandidates: [String] = [
            "face.sad.fill",
            "face.frowning.fill",
            "face.frown.fill",
        ]

        let candidates = isFilled ? filledCandidates : outlineCandidates

        return candidates.first(where: { isSFIconAvailable($0) })
    }

    private static func isSFIconAvailable(_ name: String) -> Bool {
        #if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #else
        return UIImage(systemName: name) != nil
        #endif
    }
    
    var label: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .great: return "Great"
        }
    }
}
