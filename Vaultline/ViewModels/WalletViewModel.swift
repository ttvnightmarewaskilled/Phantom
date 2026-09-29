import Foundation
import Observation

enum WalletError: LocalizedError {
    case invalidAmount, insufficientBalance, sameAsset, invalidRecipient
    case assetNotFound, duplicateTicker, invalidAsset

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter a valid amount."
        case .insufficientBalance: "Insufficient balance."
        case .sameAsset: "Choose two different assets."
        case .invalidRecipient: "Enter a valid recipient address."
        case .assetNotFound: "Asset not found."
        case .duplicateTicker: "An asset with that ticker already exists."
        case .invalidAsset: "Name and ticker are required."
        }
    }
}

struct SwapQuote: Equatable {
    let fromID: Asset.ID
    let toID: Asset.ID
    let fromTicker: String
    let toTicker: String
    let payAmount: Double
    let receiveAmount: Double
    /// Units of "to" received per 1 unit of "from".
    let rate: Double
    let priceImpactPercent: Double
    let networkFeeUSD: Double
    let payUSD: Double
}

@MainActor
@Observable
final class WalletViewModel {
    private(set) var state: WalletState
    @ObservationIgnored private let store: WalletStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(store: WalletStore = WalletStore()) {
        self.store = store
        self.state = store.load() ?? .seed()
        Haptics.isEnabled = state.settings.hapticsEnabled
        for tx in state.transactions where tx.status == .pending {
            scheduleSettlement(for: tx.id, after: 2)
        }
    }

    // MARK: - Derived values (all dynamic)

    var assets: [Asset] { state.assets }
    var address: String { state.address }
    var walletName: String { state.walletName }
    var settings: WalletSettings { state.settings }

    var totalValue: Double { state.assets.reduce(0) { $0 + $1.usdValue } }
    var change24hUSD: Double { state.assets.reduce(0) { $0 + $1.usdChange24h } }
    var change24hPercent: Double {
        let previous = totalValue - change24hUSD
        return previous > 0 ? change24hUSD / previous * 100 : 0
    }

    var transactions: [Transaction] { state.transactions.sorted { $0.date > $1.date } }
    var heldCoinIDs: [String] { state.assets.compactMap(\.coinID) }

    func asset(id: Asset.ID) -> Asset? { state.assets.first { $0.id == id } }
    func asset(ticker: String) -> Asset? {
        state.assets.first { $0.ticker.caseInsensitiveCompare(ticker) == .orderedSame }
    }
    func transaction(id: Transaction.ID) -> Transaction? { state.transactions.first { $0.id == id } }

    func portfolioSeries(_ period: ChartPeriod) -> [ChartPoint] {
        ChartGenerator.series(endValue: totalValue, change24hPercent: change24hPercent,
                              period: period, seedKey: "portfolio")
    }

    func priceSeries(for asset: Asset, period: ChartPeriod) -> [ChartPoint] {
        ChartGenerator.series(endValue: asset.price, change24hPercent: asset.change24h,
                              period: period, seedKey: asset.ticker)
    }

    // MARK: - Live prices

    /// Applies live market data to assets that have a coin id and weren't hand-priced.
    func applyLivePrices(_ lookup: (String) -> MarketCoin?) {
        guard state.settings.livePricesEnabled else { return }
        var changed = false
        for index in state.assets.indices {
            guard let id = state.assets[index].coinID,
                  state.assets[index].pinnedPrice != true,
                  let coin = lookup(id), coin.price > 0 else { continue }
            state.assets[index].price = coin.price
            state.assets[index].change24h = coin.change24h
            state.assets[index].imageURL = coin.image
            changed = true
        }
        if changed { scheduleSave() }
    }

    // MARK: - Swap

    func quote(fromID: Asset.ID, toID: Asset.ID, payAmount: Double) -> SwapQuote? {
        guard payAmount > 0, fromID != toID,
              let from = asset(id: fromID), let to = asset(id: toID),
              from.price > 0, to.price > 0 else { return nil }
        let payUSD = payAmount * from.price
        // Simulated pool depth: bigger trades move the price more.
        let impact = min(15, payUSD / 2_000_000 * 100 + 0.02)
        let receive = payUSD * (1 - impact / 100) / to.price
        return SwapQuote(fromID: fromID, toID: toID, fromTicker: from.ticker, toTicker: to.ticker,
                         payAmount: payAmount, receiveAmount: receive, rate: from.price / to.price,
                         priceImpactPercent: impact, networkFeeUSD: AppConfig.networkFeeUSD, payUSD: payUSD)
    }

    @discardableResult
    func executeSwap(_ quote: SwapQuote) throws -> Transaction {
        guard let fromIndex = state.assets.firstIndex(where: { $0.id == quote.fromID }),
              let toIndex = state.assets.firstIndex(where: { $0.id == quote.toID })
        else { throw WalletError.assetNotFound }
        guard quote.payAmount > 0 else { throw WalletError.invalidAmount }
        guard state.assets[fromIndex].quantity >= quote.payAmount else { throw WalletError.insufficientBalance }

        let from = state.assets[fromIndex], to = state.assets[toIndex]
        let tx = Transaction(
            kind: .swapped, status: .completed, ticker: from.ticker, amount: quote.payAmount,
            usdValue: quote.payAmount * from.price, date: .now, counterparty: "Swap",
            feeUSD: quote.networkFeeUSD, secondaryTicker: to.ticker,
            secondaryAmount: quote.receiveAmount, signature: AddressTools.random(length: 64)
        )
        mutate {
            $0.assets[fromIndex].quantity -= quote.payAmount
            $0.assets[toIndex].quantity += quote.receiveAmount
            $0.transactions.append(tx)
        }
        Haptics.success()
        return tx
    }

    /// Simulated purchase of a market coin using the USDC balance.
    @discardableResult
    func buyCoin(_ coin: MarketCoin, usdAmount: Double) throws -> Transaction {
        guard usdAmount > 0, coin.price > 0 else { throw WalletError.invalidAmount }
        guard let usdc = asset(ticker: "USDC") else { throw WalletError.assetNotFound }
        let payAmount = usdAmount / max(usdc.price, 0.0001)
        guard usdc.quantity >= payAmount else { throw WalletError.insufficientBalance }

        let ticker = coin.ticker
        if asset(ticker: ticker) == nil {
            try addAsset(name: coin.name, ticker: ticker, quantity: 0, price: coin.price,
                         change24h: coin.change24h, colorHex: coin.colorHex,
                         coinID: coin.id, imageURL: coin.image)
        }
        guard let target = asset(ticker: ticker),
              let quote = quote(fromID: usdc.id, toID: target.id, payAmount: payAmount)
        else { throw WalletError.assetNotFound }
        return try executeSwap(quote)
    }

    // MARK: - Send / Receive

    @discardableResult
    func send(assetID: Asset.ID, recipient: String, amount: Double) throws -> Transaction {
        guard let index = state.assets.firstIndex(where: { $0.id == assetID }) else { throw WalletError.assetNotFound }
        guard AddressTools.isValid(recipient) else { throw WalletError.invalidRecipient }
        guard amount > 0 else { throw WalletError.invalidAmount }
        guard state.assets[index].quantity >= amount else { throw WalletError.insufficientBalance }

        let asset = state.assets[index]
        let tx = Transaction(
            kind: .sent, status: .pending, ticker: asset.ticker, amount: amount,
            usdValue: amount * asset.price, date: .now, counterparty: recipient,
            feeUSD: AppConfig.networkFeeUSD, signature: AddressTools.random(length: 64)
        )
        mutate {
            $0.assets[index].quantity -= amount
            $0.transactions.append(tx)
        }
        scheduleSettlement(for: tx.id, after: 4)
        Haptics.success()
        return tx
    }

    private func scheduleSettlement(for id: Transaction.ID, after seconds: Double) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            self?.complete(id)
        }
    }

    private func complete(_ id: Transaction.ID) {
        guard let index = state.transactions.firstIndex(where: { $0.id == id }),
              state.transactions[index].status == .pending else { return }
        mutate { $0.transactions[index].status = .completed }
        Haptics.impact(.soft)
    }

    // MARK: - Demo controls

    func addAsset(name: String, ticker: String, quantity: Double, price: Double,
                  change24h: Double, colorHex: String = "#7C5CFF",
                  coinID: String? = nil, imageURL: String? = nil) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !name.isEmpty, !ticker.isEmpty else { throw WalletError.invalidAsset }
        guard asset(ticker: ticker) == nil else { throw WalletError.duplicateTicker }
        mutate {
            $0.assets.append(Asset(name: name, ticker: ticker, quantity: max(0, quantity),
                                   price: max(0, price), change24h: change24h, colorHex: colorHex,
                                   coinID: coinID, imageURL: imageURL))
        }
        Haptics.success()
    }

    func updateAsset(_ updated: Asset) throws {
        guard let index = state.assets.firstIndex(where: { $0.id == updated.id }) else { throw WalletError.assetNotFound }
        let ticker = updated.ticker.trimmingCharacters(in: .whitespaces).uppercased()
        let name = updated.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !ticker.isEmpty else { throw WalletError.invalidAsset }
        if let other = asset(ticker: ticker), other.id != updated.id { throw WalletError.duplicateTicker }

        var clean = updated
        clean.name = name
        clean.ticker = ticker
        clean.quantity = max(0, clean.quantity)
        clean.price = max(0, clean.price)
        // A hand-edited price should stick instead of being overwritten by live data.
        if abs(clean.price - state.assets[index].price) > 1e-12 { clean.pinnedPrice = true }
        mutate { $0.assets[index] = clean }
        Haptics.impact(.light)
    }

    func removeAsset(id: Asset.ID) {
        mutate { $0.assets.removeAll { $0.id == id } }
        Haptics.warning()
    }

    /// Creates a simulated transaction. Received/Sent can optionally adjust the balance.
    func createTransaction(kind: TransactionKind, status: TransactionStatus, ticker: String,
                           amount: Double, date: Date = .now, counterparty: String? = nil,
                           secondaryTicker: String? = nil, secondaryAmount: Double? = nil,
                           applyToBalance: Bool) throws {
        guard amount > 0 else { throw WalletError.invalidAmount }
        guard let index = state.assets.firstIndex(where: {
            $0.ticker.caseInsensitiveCompare(ticker) == .orderedSame
        }) else { throw WalletError.assetNotFound }

        let price = state.assets[index].price
        let tx = Transaction(
            kind: kind, status: status, ticker: state.assets[index].ticker, amount: amount,
            usdValue: amount * price, date: date,
            counterparty: kind == .swapped ? "Swap" : (counterparty ?? AddressTools.random(length: 44)),
            feeUSD: AppConfig.networkFeeUSD, secondaryTicker: secondaryTicker,
            secondaryAmount: secondaryAmount, signature: AddressTools.random(length: 64)
        )
        mutate {
            if applyToBalance {
                switch kind {
                case .received: $0.assets[index].quantity += amount
                case .sent: $0.assets[index].quantity = max(0, $0.assets[index].quantity - amount)
                case .swapped: break
                }
            }
            $0.transactions.append(tx)
        }
        if status == .pending { scheduleSettlement(for: tx.id, after: 4) }
        Haptics.success()
    }

    func deleteTransaction(id: Transaction.ID) {
        mutate { $0.transactions.removeAll { $0.id == id } }
        Haptics.warning()
    }

    func renameWallet(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { $0.walletName = trimmed }
    }

    /// Restores seed data. User settings are kept.
    func resetDemoData() {
        state = .seed(settings: state.settings)
        saveNow()
        for tx in state.transactions where tx.status == .pending {
            scheduleSettlement(for: tx.id, after: 2)
        }
        Haptics.warning()
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout WalletSettings) -> Void) {
        mutate { change(&$0.settings) }
        Haptics.isEnabled = state.settings.hapticsEnabled
    }

    // MARK: - Persistence

    private func mutate(_ change: (inout WalletState) -> Void) {
        change(&state)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        store.save(state)
    }
}
