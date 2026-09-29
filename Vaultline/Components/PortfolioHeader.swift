import SwiftUI

struct PortfolioHeader: View {
    let total: Double
    let change: Double
    let percent: Double
    let hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(hidden ? "••••••" : Format.usd(total))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText(value: total))
                .animation(.snappy, value: total)
            HStack(spacing: 8) {
                Text(hidden ? "•••" : Format.signedUSD(change))
                    .foregroundStyle(Color.trend(change))
                ChangeLabel(percent: percent)
                Text("24h").foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("portfolio_header")
    }
}
