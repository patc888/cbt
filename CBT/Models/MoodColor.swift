import SwiftUI

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

    func iconColor(with themeColor: Color) -> Color {
        switch self {
        case .veryLow: return themeColor
        default: return color(with: themeColor)
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        icon(size: 28)
    }

    @ViewBuilder
    func icon(size: CGFloat) -> some View {
        MoodFaceIcon(mood: self)
            .frame(width: size, height: size)
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

private struct MoodFaceIcon: View {
    let mood: MoodColor

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.075, 1.7)
            let filled = mood == .veryLow || mood == .great

            ZStack {
                if filled {
                    Circle()
                        .fill()

                    faceFeatures(size: size, lineWidth: lineWidth)
                        .blendMode(.destinationOut)
                } else {
                    Circle()
                        .stroke(lineWidth: lineWidth)

                    faceFeatures(size: size, lineWidth: lineWidth)
                }
            }
            .compositingGroup()
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func faceFeatures(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill()
                .frame(width: size * 0.12, height: size * 0.12)
                .position(x: size * 0.37, y: size * 0.39)

            Circle()
                .fill()
                .frame(width: size * 0.12, height: size * 0.12)
                .position(x: size * 0.63, y: size * 0.39)

            MoodMouthShape(kind: mouthKind)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.42, height: size * 0.2)
                .position(x: size * 0.5, y: mouthYPosition(for: size))
        }
        .frame(width: size, height: size)
    }

    private var mouthKind: MoodMouthShape.Kind {
        switch mood {
        case .veryLow, .low: return .frown
        case .neutral, .good, .great: return .smile
        }
    }

    private func mouthYPosition(for size: CGFloat) -> CGFloat {
        switch mouthKind {
        case .frown: return size * 0.68
        case .smile: return size * 0.61
        }
    }
}

private struct MoodMouthShape: Shape {
    enum Kind {
        case frown
        case smile
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch kind {
        case .frown:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY)
            )
        case .smile:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )
        }

        return path
    }
}
