import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AppIconView: View {
    var size: CGFloat = 60
    var isTabIcon: Bool = false

    private let brandPurple = Color(red: 156/255, green: 128/255, blue: 252/255)

    var body: some View {
        if isTabIcon {
            Image(systemName: "brain.head.profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(brandPurple)
        } else {
            actualIconOrFallback
        }
    }

    @ViewBuilder
    private var actualIconOrFallback: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: "AppBrandingIcon") {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else if let image = getBundleIcon() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else if let image = UIImage(named: "AppIcon 2") ?? UIImage(named: "AppIcon") ?? UIImage(named: "SubscriptionIcon") {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else {
            codeDrawnIcon
        }
        #else
        if let nsImage = NSImage(named: "AppBrandingIcon") {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else if let nsImage = NSImage(named: "AppIcon 2") ?? NSImage(named: "AppIcon") ?? NSImage(named: "SubscriptionIcon") {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225))
        } else {
            codeDrawnIcon
        }
        #endif
    }

    #if canImport(UIKit)
    private func getBundleIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    #endif

    private var codeDrawnIcon: some View {
        let dialSize = size * 0.45

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(brandPurple)
                .frame(width: size, height: size)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: dialSize, height: dialSize)

                    Capsule()
                        .fill(brandPurple)
                        .frame(width: dialSize * 0.12, height: dialSize * 0.45)
                        .offset(y: -dialSize * 0.1)
                        .rotationEffect(.degrees(-30))
                }
                .padding(.top, size * 0.15)

                Spacer()

                VStack(spacing: size * 0.08) {
                    HStack(spacing: size * 0.4) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.11, height: size * 0.11)
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.11, height: size * 0.11)
                    }

                    Path { path in
                        let width = size * 0.3
                        let height = size * 0.12
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(
                            to: CGPoint(x: width, y: 0),
                            control: CGPoint(x: width / 2, y: height)
                        )
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                    .frame(width: size * 0.3, height: size * 0.12)
                }
                .padding(.bottom, size * 0.15)
            }
        }
    }
}
