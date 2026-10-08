import Foundation
import Observation

enum PriceError: Error {
    case rateLimited(TimeInterval)
    case http(Int)
    case badResponse

    var message: String {
        switch self {
        case .rateLimited: "Price provider is rate-limiting requests. Showing saved prices."
        case .http(let code): "Price provider error (\(code)). Showing saved prices."
        case .badResponse: "Unexpected price data. Showing saved prices."
        }
    }
}

private struct MarketCache: Codable {
    var updated: Date
    var top: [MarketCoin]
    var meme: [MarketCoin]
    var held: [MarketCoin]
}

private struct MarketChartResponse: Decodable {
    let prices: [[Double]]
}

private struct HistoryEntry {
    let date: Date
    let points: [ChartPoint]
}

/// Live market data from CoinGecko's public API (no key needed; an optional free Demo key raises limits).
/// Everything is cached on disk so the app still opens offline.
@MainActor
@Observable
final class PriceService {
    private(set) var topCoins: [MarketCoin] = []
    private(set) var memeCoins: [MarketCoin] = []
    private(set) var heldCoins: [String: MarketCoin] = [:]
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var watchlist: Set<String> = []
    private(set) var apiKey = ""

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let session = URLSession.shared
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private var historyCache: [String: HistoryEntry] = [:]
    @ObservationIgnored private var backoffUntil: Date?

    private static let base = "https://api.coingecko.com/api/v3"
    private enum Keys {
        static let watchlist = "vaultline.watchlist"
        static let apiKey = "vaultline.coingecko.key"
    }

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheURL = dir.appendingPathComponent("markets_cache.json")
        watchlist = Set(defaults.stringArray(forKey: Keys.watchlist) ?? [])
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        loadCache()
    }

    // MARK: - Lookup

    /// Unique coins from every list we have.
    var allCoins: [MarketCoin] {
        var seen = Set<String>()
        return (topCoins + memeCoins + Array(heldCoins.values)).filter { seen.insert($0.id).inserted }
    }

    func coin(id: String) -> MarketCoin? {
        heldCoins[id] ?? topCoins.first { $0.id == id } ?? memeCoins.first { $0.id == id }
    }

    // MARK: - Watchlist / key

    func isWatched(_ id: String) -> Bool { watchlist.contains(id) }

    func toggleWatch(_ id: String) {
        if watchlist.contains(id) { watchlist.remove(id) } else { watchlist.insert(id) }
        defaults.set(Array(watchlist), forKey: Keys.watchlist)
        Haptics.selection()
    }

    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(apiKey, forKey: Keys.apiKey)
    }

    // MARK: - Refresh

    func refresh(force: Bool = false, heldIDs: [String] = []) async {
        guard !isLoading else { return }
        if !force, let until = backoffUntil, until > .now { return }
        if !force, let last = lastUpdated, Date.now.timeIntervalSince(last) < 50 { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Sequential on purpose: gentle on the free rate limit.
            let top = try await fetchMarkets(category: nil, ids: nil)
            let meme = try await fetchAllMemes()
            var held: [MarketCoin] = []
            if !heldIDs.isEmpty { held = try await fetchMarkets(category: nil, ids: heldIDs) }

            topCoins = top
            memeCoins = meme
            heldCoins = Dictionary(held.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            lastUpdated = .now
            errorMessage = nil
            saveCache()
        } catch let error as PriceError {
            errorMessage = error.message
        } catch {
            errorMessage = "Offline. Showing saved prices."
        }
    }

    private static let memePageSize = 250   // CoinGecko's maximum per page
    private static let memeMaxPages = 8     // up to 2,000 meme coins

    /// Every coin in CoinGecko's meme category, fetched page by page.
    /// If a later page fails (e.g. rate limit), the coins loaded so far are kept.
    private func fetchAllMemes() async throws -> [MarketCoin] {
        var all = try await fetchMarkets(category: "meme-token", ids: nil, page: 1,
                                         perPage: Self.memePageSize, sparkline: true)
        var lastCount = all.count
        var page = 2
        while lastCount == Self.memePageSize, page <= Self.memeMaxPages {
            guard let next = try? await fetchMarkets(category: "meme-token", ids: nil, page: page,
                                                     perPage: Self.memePageSize, sparkline: false)
            else { break }
            all += next
            lastCount = next.count
            page += 1
        }
        var seen = Set<String>()
        return all.filter { seen.insert($0.id).inserted }
    }

    private func fetchMarkets(category: String?, ids: [String]?, page: Int = 1,
                              perPage: Int? = nil, sparkline: Bool? = nil) async throws -> [MarketCoin] {
        var items = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: String(perPage ?? (ids == nil ? 100 : 50))),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sparkline", value: (sparkline ?? (ids == nil)) ? "true" : "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h")
        ]
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        if let ids { items.append(URLQueryItem(name: "ids", value: ids.joined(separator: ","))) }
        return try await get("/coins/markets", items)
    }

    // MARK: - History

    func history(coinID: String, period: ChartPeriod) async throws -> [ChartPoint] {
        let key = "\(coinID)|\(period.rawValue)"
        if let cached = historyCache[key], Date.now.timeIntervalSince(cached.date) < 300 {
            return cached.points
        }
        if let until = backoffUntil, until > .now { throw PriceError.rateLimited(until.timeIntervalSinceNow) }

        let days: String
        switch period {
        case .day: days = "1"
        case .week: days = "7"
        case .month: days = "30"
        case .year: days = "365"
        }
        let response: MarketChartResponse = try await get(
            "/coins/\(coinID)/market_chart",
            [URLQueryItem(name: "vs_currency", value: "usd"), URLQueryItem(name: "days", value: days)]
        )

        let raw = response.prices.filter { $0.count >= 2 }
        guard raw.count > 1 else { throw PriceError.badResponse }
        let step = max(1, raw.count / 120)
        var sampled = Swift.stride(from: 0, to: raw.count, by: step).map { raw[$0] }
        if let last = raw.last, sampled.last != last { sampled.append(last) }

        let points = sampled.enumerated().map { index, pair in
            ChartPoint(id: index, date: Date(timeIntervalSince1970: pair[0] / 1000), value: pair[1])
        }
        historyCache[key] = HistoryEntry(date: .now, points: points)
        return points
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: Self.base + path)
        components?.queryItems = query
        guard let url = components?.url else { throw PriceError.badResponse }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        if !apiKey.isEmpty { request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PriceError.badResponse }
        if http.statusCode == 429 {
            let retry = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60
            backoffUntil = Date.now.addingTimeInterval(retry)
            throw PriceError.rateLimited(retry)
        }
        guard (200..<300).contains(http.statusCode) else { throw PriceError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PriceError.badResponse
        }
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let cache = try? decoder.decode(MarketCache.self, from: data) else { return }
        topCoins = cache.top
        memeCoins = cache.meme
        heldCoins = Dictionary(cache.held.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        lastUpdated = cache.updated
    }

    private func saveCache() {
        let cache = MarketCache(updated: lastUpdated ?? .now, top: topCoins, meme: memeCoins,
                                held: Array(heldCoins.values))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(cache) {
            try? data.write(to: cacheURL, options: [.atomic])
        }
    }
}
