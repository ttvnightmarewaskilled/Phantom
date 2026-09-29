import Foundation

struct MarketCoin: Identifiable, Codable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double?
    let marketCap: Double?
    let marketCapRank: Int?
    let priceChangePercentage24h: Double?
    let sparklineIn7d: Sparkline?

    struct Sparkline: Codable, Hashable {
        let price: [Double]
    }

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case sparklineIn7d = "sparkline_in_7d"
    }

    var price: Double { currentPrice ?? 0 }
    var change24h: Double { priceChangePercentage24h ?? 0 }
    var ticker: String { symbol.uppercased() }

    private static let palette = ["#8A63FF", "#2775CA", "#2DD4A3", "#FF8A4C", "#E5484D", "#F5A623", "#0EA5E9", "#D946EF"]

    var colorHex: String {
        let index = Int(ChartGenerator.stableSeed(id) % UInt64(Self.palette.count))
        return Self.palette[index]
    }
}
