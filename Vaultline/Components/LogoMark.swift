import SwiftUI

struct LogoMark: View {
    var size: CGFloat = 36

    var body: some View {
        Text(AppConfig.logoEmoji)
            .font(.system(size: size * 0.62))
            .frame(width: size, height: size)
            .background(AppConfig.accent.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct DemoBadge: View {
    var body: some View {
        Text(AppConfig.demoBadgeText)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppConfig.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppConfig.accent.opacity(0.15), in: Capsule())
            .accessibilityLabel("Demo mode. Balances are simulated.")
    }
}
