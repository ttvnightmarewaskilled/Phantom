import SwiftUI

struct AssetDetailView: View {
    let assetID: Asset.ID
    @Environment(WalletViewModel.self) private var wallet
    @State private var sheet: WalletSheet?

    var body: some View {
        Group {
            if let asset = wallet.asset(id: assetID) {
                content(asset)
            } else {
                ContentUnavailableView("Asset removed", systemImage: "questionmark.circle")
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { WalletSheetView(sheet: $0) }
    }

    private func content(_ a: Asset) -> some View {
        let hidden = wallet.settings.hideBalances
        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    TokenIcon(ticker: a.ticker, colorHex: a.colorHex, imageURL: a.imageURL, size: 72)
                    Text(a.name).font(.title2.weight(.semibold))
                    Text(a.ticker).foregroundStyle(.secondary)
                    Text(Format.price(a.price))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText(value: a.price))
                        .animation(.snappy, value: a.price)
                    HStack(spacing: 6) {
                        ChangeLabel(percent: a.change24h)
                        Text("24h").foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityElement(children: .combine)

                PeriodChart(
                    coinID: wallet.settings.livePricesEnabled ? a.coinID : nil,
                    simulated: { wallet.priceSeries(for: a, period: $0) },
                    format: { Format.price($0) }
                )

                VStack(spacing: 0) {
                    KeyValueRow(key: "Your balance", value: hidden ? "••••" : "\(Format.quantity(a.quantity)) \(a.ticker)")
                    Divider().padding(.leading, 16)
                    KeyValueRow(key: "USD value", value: hidden ? "••••" : Format.usd(a.usdValue))
                    Divider().padding(.leading, 16)
                    KeyValueRow(key: "24h change", value: hidden ? "••••" : Format.signedUSD(a.usdChange24h),
                                valueColor: Color.trend(a.usdChange24h))
                }
                .cardStyle()

                HStack(spacing: 10) {
                    ActionButton(title: "Buy", symbol: "plus") {
                        sheet = .swap(from: wallet.asset(ticker: "USDC")?.id, to: a.id)
                    }
                    ActionButton(title: "Sell", symbol: "minus", enabled: a.quantity > 0) {
                        sheet = .swap(from: a.id, to: wallet.asset(ticker: "USDC")?.id)
                    }
                    ActionButton(title: "Send", symbol: "arrow.up") { sheet = .send(a.id) }
                    ActionButton(title: "Receive", symbol: "arrow.down") { sheet = .receive(a.id) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}
