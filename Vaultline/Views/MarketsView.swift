import SwiftUI

enum MarketFilter: String, CaseIterable, Identifiable {
    case top = "Top", meme = "Memes", watchlist = "Watchlist", gainers = "Gainers", losers = "Losers"
    var id: String { rawValue }
}

struct MarketsView: View {
    @Environment(PriceService.self) private var prices
    @Environment(WalletViewModel.self) private var wallet
    @State private var filter: MarketFilter = .top
    @State private var search = ""

    private var coins: [MarketCoin] {
        var list: [MarketCoin]
        switch filter {
        case .top: list = prices.topCoins
        case .meme: list = prices.memeCoins
        case .watchlist: list = prices.allCoins.filter { prices.isWatched($0.id) }
        case .gainers: list = prices.allCoins.filter { $0.change24h > 0 }.sorted { $0.change24h > $1.change24h }
        case .losers: list = prices.allCoins.filter { $0.change24h < 0 }.sorted { $0.change24h < $1.change24h }
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.symbol.localizedCaseInsensitiveContains(query)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    chips
                    status
                    if filter == .meme {
                        Label("Meme coins are extremely volatile and many go to zero. This app only simulates trades.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    list
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.snappy, value: filter)
            }
            .background(Color.appBackground)
            .navigationTitle("Markets")
            .searchable(text: $search, prompt: "Search coins")
            .refreshable {
                await prices.refresh(force: true, heldIDs: wallet.heldCoinIDs)
                wallet.applyLivePrices { prices.coin(id: $0) }
            }
            .navigationDestination(for: MarketCoin.self) { CoinDetailView(coin: $0) }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarketFilter.allCases) { item in
                    Button {
                        Haptics.selection()
                        filter = item
                    } label: {
                        Text(item.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(filter == item ? Color.white : Color.primary)
                            .background(filter == item ? AppConfig.accent : Color.cardBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error = prices.errorMessage {
            Label(error, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let updated = prices.lastUpdated {
            HStack(spacing: 4) {
                Text("Updated")
                Text(updated, style: .relative)
                Text("ago")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var list: some View {
        if coins.isEmpty {
            if prices.isLoading && prices.topCoins.isEmpty {
                ProgressView("Loading markets…").frame(maxWidth: .infinity).padding(.top, 40)
            } else if filter == .watchlist {
                ContentUnavailableView("No watched coins", systemImage: "star",
                                       description: Text("Open a coin and tap the star to add it here."))
            } else if prices.topCoins.isEmpty {
                ContentUnavailableView {
                    Label("No market data", systemImage: "chart.line.uptrend.xyaxis")
                } description: {
                    Text("Connect to the internet to load prices.")
                } actions: {
                    Button("Try again") {
                        Task { await prices.refresh(force: true, heldIDs: wallet.heldCoinIDs) }
                    }
                }
            } else {
                ContentUnavailableView.search
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(coins.enumerated()), id: \.element.id) { index, coin in
                    NavigationLink(value: coin) {
                        MarketRow(coin: coin, watched: prices.isWatched(coin.id))
                    }
                    .buttonStyle(PressableStyle())
                    .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                    .contextMenu {
                        Button(prices.isWatched(coin.id) ? "Remove from watchlist" : "Add to watchlist",
                               systemImage: prices.isWatched(coin.id) ? "star.slash" : "star") {
                            prices.toggleWatch(coin.id)
                        }
                    }
                    if index < coins.count - 1 { Divider().padding(.leading, 68) }
                }
            }
            .cardStyle()
        }
    }
}

struct MarketRow: View {
    let coin: MarketCoin
    var watched = false

    var body: some View {
        HStack(spacing: 12) {
            TokenIcon(ticker: coin.ticker, colorHex: coin.colorHex, imageURL: coin.image)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(coin.name).font(.body.weight(.semibold)).lineLimit(1)
                    if watched { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
                }
                Text(coin.ticker).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let values = coin.sparklineIn7d?.price, values.count > 1 {
                Sparkline(values: values, color: Color.trend((values.last ?? 0) - (values.first ?? 0)))
                    .frame(width: 56, height: 26)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.price(coin.price)).font(.body.weight(.semibold))
                ChangeLabel(percent: coin.change24h).font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("market_row_\(coin.ticker)")
    }
}
