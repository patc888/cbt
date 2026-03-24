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
                #if os(macOS) || targetEnvironment(macCatalyst)
                Image(systemName: MoodColor.frownSymbolName(isFilled: false))
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #else
                Text("\u{2639}\u{FE0E}")
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #endif
            case .low:
                #if os(macOS) || targetEnvironment(macCatalyst)
                Image(systemName: MoodColor.frownSymbolName(isFilled: true))
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #else
                Text("\u{2639}\u{FE0E}")
                    .font(.system(size: 20).weight(.black))
                    .scaleEffect(1.75)
                    .offset(y: -1)
                #endif
            case .neutral:
                Image(systemName: "face.smiling")
            case .good:
                Image(systemName: "face.smiling")
            case .great:
                Image(systemName: "face.smiling.fill")
            }
        }
    }

    private static func frownSymbolName(isFilled: Bool) -> String {
        // SF Symbols face variants differ across OS versions / SF Symbols packs.
        // Use availability checks so we don't end up with blank icons.
        let outlineCandidates: [String] = [
            "face.dashed",
            "face.meh",
            "face.sad",
            "face.frowning",
            "face.frown",
            "face.smiling.inverse",
            "face.angry",
        ]

        let filledCandidates: [String] = [
            "face.dashed.fill",
            "face.meh.fill",
            "face.sad.fill",
            "face.frowning.fill",
            "face.frown.fill",
            "face.smiling.inverse.fill",
            "face.angry.fill",
        ]

        let candidates = isFilled ? filledCandidates : outlineCandidates

        return candidates.first(where: { isSFIconAvailable($0) })
            ?? (isFilled ? "face.smiling.fill" : "face.smiling")
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
