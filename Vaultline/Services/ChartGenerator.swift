import Foundation

struct ChartPoint: Identifiable, Equatable {
    let id: Int
    let date: Date
    let value: Double
}

enum ChartPeriod: String, CaseIterable, Identifiable {
    case day = "1D", week = "1W", month = "1M", year = "1Y"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .day: 86_400
        case .week: 604_800
        case .month: 2_592_000
        case .year: 31_536_000
        }
    }
    var pointCount: Int {
        switch self {
        case .day: 48
        case .week: 56
        case .month: 60
        case .year: 72
        }
    }
    fileprivate var volatility: Double {
        switch self {
        case .day: 0.012
        case .week: 0.025
        case .month: 0.045
        case .year: 0.12
        }
    }
    fileprivate var changeRange: ClosedRange<Double> {
        switch self {
        case .day: -3...3
        case .week: -8...12
        case .month: -15...25
        case .year: -40...120
        }
    }
    var spokenName: String {
        switch self {
        case .day: "1 day"
        case .week: "1 week"
        case .month: "1 month"
        case .year: "1 year"
        }
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Deterministic simulated history that always ends at the live value,
/// so charts stay in sync with balance/price edits.
enum ChartGenerator {
    static func stableSeed(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    static func series(endValue: Double, change24hPercent: Double, period: ChartPeriod,
                       seedKey: String, now: Date = .now) -> [ChartPoint] {
        let n = period.pointCount
        let step = period.duration / Double(n - 1)

        func date(_ i: Int) -> Date { now.addingTimeInterval(-period.duration + step * Double(i)) }

        guard endValue > 0 else {
            return (0..<n).map { ChartPoint(id: $0, date: date($0), value: 0) }
        }

        var rng = SplitMix64(state: stableSeed(seedKey + period.rawValue))
        let pct = period == .day
            ? change24hPercent
            : Double.random(in: period.changeRange, using: &rng)
        let startValue = endValue / max(0.05, 1 + pct / 100)

        var running = 0.0
        var walk: [Double] = [0]
        for _ in 1..<n {
            running += Double.random(in: -1...1, using: &rng)
            walk.append(running)
        }

        let scale = period.volatility * max(startValue, endValue) / Double(n).squareRoot()
        let floorValue = endValue * 0.01

        return (0..<n).map { i in
            let t = Double(i) / Double(n - 1)
            let bridge = walk[i] - t * running
            let base = startValue + (endValue - startValue) * t
            return ChartPoint(id: i, date: date(i), value: max(floorValue, base + bridge * scale))
        }
    }
}
