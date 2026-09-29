import Foundation

struct Asset: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var ticker: String
    var quantity: Double
    var price: Double
    /// 24h change in percent (e.g. 3.2 means +3.2%).
    var change24h: Double
    var colorHex: String
    /// CoinGecko id, used for live prices. nil = manual only (e.g. fictional tokens).
    var coinID: String? = nil
    var imageURL: String? = nil
    /// True once the price was edited by hand; live prices then skip this asset.
    var pinnedPrice: Bool? = nil

    /// USD value = quantity × price
    var usdValue: Double { quantity * price }

    /// Dollar change over the last 24h for the current holding.
    var usdChange24h: Double {
        let previous = usdValue / max(0.05, 1 + change24h / 100)
        return usdValue - previous
    }
}
