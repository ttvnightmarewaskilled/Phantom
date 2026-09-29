import SwiftUI

struct LogoMark: View {
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(AppConfig.accent)
            .overlay {
                VShape()
                    .stroke(.white, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.26)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct VShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
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
