import SwiftUI

/// Line chart. Touch and hold, then drag to read the value at any point.
struct ChartView: View {
    let points: [ChartPoint]
    var format: (Double) -> String
    var showTime = false

    @State private var index: Int?

    private var isUp: Bool { (points.last?.value ?? 0) >= (points.first?.value ?? 0) }
    private var tint: Color { isUp ? .green : .red }

    private var range: (lo: Double, hi: Double) {
        let values = points.map(\.value)
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        return hi > lo ? (lo, hi) : (lo - 1, hi + 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            readout.frame(height: 44)
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    if points.count > 1 {
                        areaPath(in: size)
                            .fill(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0)],
                                                 startPoint: .top, endPoint: .bottom))
                        linePath(in: size)
                            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        if let i = index, points.indices.contains(i) {
                            marker(at: i, in: size)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.12)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, let drag?) = value {
                                update(x: drag.location.x, width: size.width)
                            }
                        }
                        .onEnded { _ in end() }
                )
            }
            .frame(height: 160)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityIdentifier("price_chart")
    }

    // MARK: Readout

    @ViewBuilder
    private var readout: some View {
        if let i = index, points.indices.contains(i) {
            let point = points[i]
            let start = points.first?.value ?? point.value
            let change = start > 0 ? (point.value / start - 1) * 100 : 0
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(format(point.value)).font(.title3.weight(.bold))
                    Text(Format.percent(change))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.trend(change))
                }
                Text(point.date.formatted(date: .abbreviated, time: showTime ? .shortened : .omitted))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Touch and hold the chart, then drag")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        guard let first = points.first?.value, let last = points.last?.value, first > 0 else { return "Price chart" }
        let change = (last / first - 1) * 100
        return "Price chart, \(change >= 0 ? "up" : "down") \(Format.plainPercent(change)) over the selected period"
    }

    // MARK: Geometry

    private func point(at i: Int, in size: CGSize) -> CGPoint {
        let (lo, hi) = range
        let x = size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
        let normalized = CGFloat((points[i].value - lo) / (hi - lo))
        let y = size.height - 8 - normalized * (size.height - 16)
        return CGPoint(x: x, y: y)
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        for i in points.indices {
            let p = point(at: i, in: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = linePath(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func marker(at i: Int, in size: CGSize) -> some View {
        let p = point(at: i, in: size)
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: p.x, y: 0))
                path.addLine(to: CGPoint(x: p.x, y: size.height))
            }
            .stroke(Color.secondary.opacity(0.6), lineWidth: 1)
            Circle()
                .fill(tint)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                .position(p)
        }
    }

    // MARK: Gesture

    private func update(x: CGFloat, width: CGFloat) {
        guard points.count > 1, width > 0 else { return }
        let t = min(max(x / width, 0), 1)
        let i = Int((t * CGFloat(points.count - 1)).rounded())
        if i != index {
            index = i
            Haptics.selection()
        }
    }

    private func end() {
        withAnimation(.easeOut(duration: 0.2)) { index = nil }
    }
}

/// Chart with 1D / 1W / 1M / 1Y switcher. Uses live history when a coin id is given, else simulated history.
struct PeriodChart: View {
    @Environment(PriceService.self) private var prices

    let coinID: String?
    let simulated: (ChartPeriod) -> [ChartPoint]
    let format: (Double) -> String

    @State private var period: ChartPeriod = .day
    @State private var remote: [ChartPoint]?

    private var points: [ChartPoint] { remote ?? simulated(period) }

    var body: some View {
        VStack(spacing: 12) {
            ChartView(points: points, format: format, showTime: period == .day || period == .week)
                .id("\(period.rawValue)-\(remote == nil)")
                .transition(.opacity)

            HStack(spacing: 6) {
                ForEach(ChartPeriod.allCases) { p in
                    Button {
                        guard p != period else { return }
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.25)) { period = p }
                    } label: {
                        Text(p.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(period == p ? AppConfig.accent : Color.secondary)
                            .background(period == p ? AppConfig.accent.opacity(0.14) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(p.spokenName) chart")
                    .accessibilityAddTraits(period == p ? .isSelected : [])
                    .accessibilityIdentifier("period_\(p.rawValue)")
                }
            }

            Text(remote == nil ? "Simulated history" : "Live data · CoinGecko")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .task(id: "\(period.rawValue)|\(coinID ?? "")") { await load() }
    }

    private func load() async {
        guard let coinID else {
            remote = nil
            return
        }
        do {
            let result = try await prices.history(coinID: coinID, period: period)
            withAnimation(.easeInOut(duration: 0.25)) { remote = result }
        } catch {
            if !Task.isCancelled { remote = nil }
        }
    }
}

struct Sparkline: View {
    let values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1, let lo = values.min(), let hi = values.max() else { return }
                let span = hi > lo ? hi - lo : 1
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height - CGFloat((v - lo) / span) * geo.size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
