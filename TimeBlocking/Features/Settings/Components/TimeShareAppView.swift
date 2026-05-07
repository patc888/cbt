import SwiftUI

private let appStoreURLString = "https://apps.apple.com/us/app/time-blocking/id6760246021"
private let shareMessage = "I've been using Time Blocking to master my schedule — check it out!"

struct TimeShareAppView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var copiedFeedback = false
    @State private var animateIcon = false

    private var appStoreURL: URL? { URL(string: appStoreURLString) }
    
    @Environment(\.openURL) private var openURL

    private var appIconImage: Image {
        #if os(iOS)
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let image = UIImage(named: lastIcon) {
            return Image(uiImage: image)
        }
        #elseif os(macOS)
        if let image = NSApp.applicationIconImage {
            return Image(nsImage: image)
        }
        #endif
        return Image(systemName: "clock.badge.checkmark.fill") // Fallback icon
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            ThemedBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    
                    VStack(spacing: 24) {
                        heroCard
                        
                        shareSection
                        
                        if let url = appStoreURL {
                            appStoreRow(url: url)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            // Close Button
            Button(action: {
                HapticManager.shared.lightImpact()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.primaryText.opacity(0.15))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.trailing, 20)
            .padding(.top, 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Large Animated Icon
            ZStack {
                Circle()
                    .fill(Theme.primaryAccent.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .scaleEffect(animateIcon ? 1.1 : 0.9)
                
                appIconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: colorScheme == .dark ? Theme.primaryAccent.opacity(0.3) : .clear, radius: colorScheme == .dark ? 15 : 0, x: 0, y: colorScheme == .dark ? 10 : 0)
                    .rotationEffect(.degrees(animateIcon ? 5 : -5))
            }
            .padding(.top, 60)
            .padding(.bottom, 12)

            Text("Share this App")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            
            Text("Help others master their time!")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Blocking")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    Text("Reclaim your focus. Master your time.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryAccent)
                }
                Spacer()
            }
            
            Text("The most intuitive way to plan your day, stay focused, and achieve your goals through time blocking.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                featureBadge(icon: "target", text: "Focus")
                featureBadge(icon: "calendar", text: "Routine")
                featureBadge(icon: "lock.fill", text: "Private")
            }
        }
        .padding(24)
        .background {
            Theme.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Theme.primaryAccent.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(Theme.primaryAccent)
        .background(Theme.primaryAccent.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Share Section

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Share")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .padding(.leading, 4)

            if let url = appStoreURL {
                ShareLink(
                    item: url,
                    message: Text(shareMessage),
                    preview: SharePreview("Time Blocking", image: appIconImage)
                ) {
                    premiumActionRow(
                        icon: "square.and.arrow.up.fill",
                        title: "Share with Friends",
                        subtitle: "Messages, WhatsApp, Mail",
                        color: Theme.primaryAccent,
                        isPrimary: true
                    )
                }

                Button(action: copyLink) {
                    premiumActionRow(
                        icon: copiedFeedback ? "checkmark.circle.fill" : "doc.on.doc.fill",
                        title: copiedFeedback ? "Link Copied!" : "Copy App Link",
                        subtitle: copiedFeedback ? "Ready to paste anywhere" : "Copy to your clipboard",
                        color: copiedFeedback ? Theme.successGreen : Theme.secondaryText,
                        isPrimary: false
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func premiumActionRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isPrimary: Bool
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(isPrimary ? 1 : 0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isPrimary ? .white : color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.secondaryText.opacity(0.5))
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isPrimary ? color.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : .clear, radius: colorScheme == .dark ? 10 : 0, x: 0, y: colorScheme == .dark ? 5 : 0)
    }

    // MARK: - App Store row

    private func appStoreRow(url: URL) -> some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            openURL(url)
        }) {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 0) {
                    Text("VIEW ON")
                        .font(.system(size: 10, weight: .bold))
                    Text("App Store")
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .background(Theme.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }

    private func copyLink() {
        let text = "\(shareMessage)\n\(appStoreURLString)"
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        HapticManager.shared.mediumImpact()
        withAnimation(.spring()) {
            copiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                copiedFeedback = false
            }
        }
    }
}
