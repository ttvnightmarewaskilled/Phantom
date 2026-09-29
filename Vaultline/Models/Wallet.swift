import Foundation

struct WalletSettings: Codable, Equatable {
    var hapticsEnabled = true
    var hideBalances = false
    var showDemoBadge = true
    var developerModeEnabled = false
    var livePricesEnabled = true

    init() {}

    /// Tolerant decoding so older saves keep working when settings are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        hideBalances = try c.decodeIfPresent(Bool.self, forKey: .hideBalances) ?? false
        showDemoBadge = try c.decodeIfPresent(Bool.self, forKey: .showDemoBadge) ?? true
        developerModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .developerModeEnabled) ?? false
        livePricesEnabled = try c.decodeIfPresent(Bool.self, forKey: .livePricesEnabled) ?? true
    }
}

struct WalletState: Codable, Equatable {
    var walletName: String
    var address: String
    var assets: [Asset]
    var transactions: [Transaction]
    var settings: WalletSettings

    static func seed(settings: WalletSettings = WalletSettings(), now: Date = .now) -> WalletState {
        let address = AddressTools.random(length: 44)

        let assets = [
            Asset(name: "Solana", ticker: "SOL", quantity: 12.4582, price: 148.32, change24h: 3.42,
                  colorHex: "#8A63FF", coinID: "solana"),
            Asset(name: "USD Coin", ticker: "USDC", quantity: 2450.75, price: 1.0, change24h: 0.01,
                  colorHex: "#2775CA", coinID: "usd-coin"),
            Asset(name: "Jupiter", ticker: "JUP", quantity: 1840.2, price: 0.82, change24h: -2.15,
                  colorHex: "#2DD4A3", coinID: "jupiter-exchange-solana"),
            Asset(name: "Nova", ticker: "NOVA", quantity: 52_000, price: 0.0452, change24h: 8.7,
                  colorHex: "#FF8A4C")
        ]

        func tx(_ kind: TransactionKind, _ status: TransactionStatus, _ ticker: String, _ amount: Double,
                _ usd: Double, ago: TimeInterval, to: String? = nil, _ amount2: Double? = nil) -> Transaction {
            Transaction(
                kind: kind, status: status, ticker: ticker, amount: amount, usdValue: usd,
                date: now.addingTimeInterval(-ago),
                counterparty: kind == .swapped ? "Swap" : AddressTools.random(length: 44),
                feeUSD: AppConfig.networkFeeUSD,
                secondaryTicker: to, secondaryAmount: amount2,
                signature: AddressTools.random(length: 64)
            )
        }

        let hour: TimeInterval = 3600, day: TimeInterval = 86_400
        let transactions = [
            tx(.received, .pending, "JUP", 50, 41, ago: 30),
            tx(.received, .completed, "SOL", 2.5, 370.80, ago: 2 * hour),
            tx(.swapped, .completed, "SOL", 1, 148.32, ago: day, to: "JUP", 180.5),
            tx(.sent, .completed, "USDC", 150, 150, ago: 2 * day),
            tx(.received, .completed, "USDC", 500, 500, ago: 4 * day),
            tx(.swapped, .completed, "USDC", 100, 100, ago: 6 * day, to: "NOVA", 2_212),
            tx(.received, .completed, "SOL", 5, 741.60, ago: 12 * day)
        ]

        return WalletState(walletName: "Main Wallet", address: address, assets: assets,
                           transactions: transactions, settings: settings)
    }
}

enum AddressTools {
    static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func random(length: Int) -> String {
        String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    static func isValid(_ address: String) -> Bool {
        (32...44).contains(address.count) && address.allSatisfy { alphabet.contains($0) }
    }
}
