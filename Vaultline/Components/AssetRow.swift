import SwiftUI

struct AssetRow: View {
    let asset: Asset
    var hidden = false

    var body: some View {
        HStack(spacing: 12) {
            TokenIcon(ticker: asset.ticker, colorHex: asset.colorHex, imageURL: asset.imageURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name).font(.body.weight(.semibold))
                Text("\(hidden ? "•••" : Format.quantity(asset.quantity)) \(asset.ticker)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(hidden ? "••••" : Format.usd(asset.usdValue))
                    .font(.body.weight(.semibold))
                    .contentTransition(.numericText(value: asset.usdValue))
                    .animation(.snappy, value: asset.usdValue)
                ChangeLabel(percent: asset.change24h).font(.subheadline)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
