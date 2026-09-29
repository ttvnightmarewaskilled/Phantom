import SwiftUI

struct CoinDetailView: View {
    let coin: MarketCoin
    @Environment(PriceService.self) private var prices
    @Environment(WalletViewModel.self) private var wallet
    @State private var showBuy = false

    private var live: MarketCoin { prices.coin(id: coin.id) ?? coin }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    TokenIcon(ticker: live.ticker, colorHex: live.colorHex, imageURL: live.image, size: 72)
                    Text(live.name).font(.title2.weight(.semibold))
                    Text(live.ticker).foregroundStyle(.secondary)
                    Text(Format.price(live.price))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText(value: live.price))
                        .animation(.snappy, value: live.price)
                    HStack(spacing: 6) {
                        ChangeLabel(percent: live.change24h)
                        Text("24h").foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityElement(children: .combine)

                PeriodChart(
                    coinID: coin.id,
                    simulated: { period in
                        ChartGenerator.series(endValue: live.price, change24hPercent: live.change24h,
                                              period: period, seedKey: coin.id)
                    },
                    format: { Format.price($0) }
                )

                VStack(spacing: 0) {
                    if let cap = live.marketCap { KeyValueRow(key: "Market cap", value: Format.compactUSD(cap)) }
                    if live.marketCap != nil, live.marketCapRank != nil { Divider().padding(.leading, 16) }
                    if let rank = live.marketCapRank { KeyValueRow(key: "Rank", value: "#\(rank)") }
                    if let held = wallet.asset(ticker: live.ticker) {
                        Divider().padding(.leading, 16)
                        KeyValueRow(key: "You hold", value: "\(Format.quantity(held.quantity)) \(held.ticker)")
                    }
                }
                .cardStyle()

                Button("Buy \(live.ticker)") {
                    Haptics.impact(.medium)
                    showBuy = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("coin_buy")

                Text("Simulated purchase using your demo USDC. No real money is involved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    prices.toggleWatch(coin.id)
                } label: {
                    Image(systemName: prices.isWatched(coin.id) ? "star.fill" : "star")
                        .foregroundStyle(prices.isWatched(coin.id) ? Color.yellow : Color.accentColor)
                }
                .accessibilityLabel(prices.isWatched(coin.id) ? "Remove from watchlist" : "Add to watchlist")
            }
        }
        .sheet(isPresented: $showBuy) { BuyCoinSheet(coin: live) }
    }
}

struct BuyCoinSheet: View {
    let coin: MarketCoin
    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorText: String?
    @State private var done = false
    @FocusState private var focused: Bool

    private var usdc: Asset? { wallet.asset(ticker: "USDC") }
    private var usd: Double { Format.parse(amountText) ?? 0 }
    private var estimate: Double { coin.price > 0 ? usd / coin.price : 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if done { success } else { form }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.appBackground)
            .navigationTitle(done ? "" : "Buy \(coin.ticker)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !done { Button("Cancel") { dismiss() } }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .animation(.spring(duration: 0.4), value: done)
    }

    private var form: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount (USD)").font(.subheadline).foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .focused($focused)
                    .accessibilityIdentifier("buy_amount")
                HStack(spacing: 8) {
                    ForEach([50.0, 100.0, 250.0], id: \.self) { value in
                        Button("$\(Int(value))") {
                            Haptics.selection()
                            amountText = String(Int(value))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
                if let usdc {
                    Text("Available: \(Format.usd(usdc.usdValue)) USDC")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .cardStyle()

            KeyValueRow(key: "You get (est.)", value: "\(Format.quantity(estimate)) \(coin.ticker)").cardStyle()

            if let errorText { Text(errorText).font(.footnote).foregroundStyle(.red) }

            Button("Buy \(coin.ticker)") { buy() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(usd <= 0)
                .accessibilityIdentifier("buy_confirm")
        }
    }

    private var success: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: done)
                .padding(.top, 24)
            Text("Purchase complete").font(.title2.weight(.bold))
            Text("\(Format.quantity(estimate)) \(coin.ticker) added to your wallet")
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func buy() {
        focused = false
        do {
            try wallet.buyCoin(coin, usdAmount: usd)
            done = true
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }
}
