import SwiftUI

struct AppIconView: View {
    var size: CGFloat = 64
    
    var body: some View {
        Image("AppIconImage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: size * 0.05, x: 0, y: size * 0.02)
    }
}

#Preview {
    VStack(spacing: 20) {
        AppIconView(size: 64)
        AppIconView(size: 120)
    }
    .padding()
}
