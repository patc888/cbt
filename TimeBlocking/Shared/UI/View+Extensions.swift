import SwiftUI

extension View {
    @ViewBuilder
    func timeSubscriptionPresentation(isPresented: Binding<Bool>) -> some View {
#if os(macOS)
        sheet(isPresented: isPresented) {
            SubscriptionView()
        }
#else
        fullScreenCover(isPresented: isPresented) {
            SubscriptionView()
        }
#endif
    }
}
