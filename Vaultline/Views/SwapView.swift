import SwiftUI

struct SwapView: View {
    @Environment(WalletViewModel.self) private var wallet
    @Environment(PriceService.self) private var prices
    @Environment(\.dismiss) private var dismiss

    var presetFrom: Asset.ID? = nil
    var presetTo: Asset.ID? = nil
    var isSheet = false

    @State private var fromID: Asset.ID?
    @State private var toID: Asset.ID?
    @State private var payText = ""
    @State private var review: ReviewItem?   // frozen copy of the quote, so the sheet never goes blank
    @State private var showPicker = false
    @State private var browsedIDs: Set<Asset.ID> = []   // empty assets added just by picking a coin
    @FocusState private var focused: Bool

    private var fromAsset: Asset? { fromID.flatMap { wallet.asset(id: $0) } }
    private var toAsset: Asset? { toID.flatMap { wallet.asset(id: $0) } }

    private var quote: SwapQuote? {
        guard let fromID, let toID, let amount = Format.parse(payText) else { return nil }
        return wallet.quote(fromID: fromID, toID: toID, payAmount: amount)
    }

    private var validation: String? {
        guard let amount = Format.parse(payText), amount > 0, let from = fromAsset else { return nil }
        return amount > from.quantity ? "Insufficient \(from.ticker) balance" : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    payCard
                    flipButton
                    receiveCard
                    if let quote { detailsCard(quote) }
                    if let validation {
                        Text(validation).font(.footnote).foregroundStyle(.red)
                    }
                    Button("Review swap") {
                        focused = false
                        Haptics.impact(.medium)
                        if let quote { review = ReviewItem(quote: quote) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(quote == nil || validation != nil)
                    .padding(.top, 8)
                    .accessibilityIdentifier("swap_review")
                }
                .padding(16)
                .animation(.snappy, value: quote)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .navigationTitle("Swap")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isSheet { Button("Close") { dismiss() } }
                }
            }
            .sheet(item: $review) { item in
                ReviewSwapSheet(quote: item.quote) { payText = "" }
            }
            .sheet(isPresented: $showPicker) {
                TokenPickerSheet(held: wallet.assets, coins: prices.allCoins,
                                 onPickAsset: pickReceiveAsset, onPickCoin: pickReceiveCoin)
            }
        }
        .onAppear(perform: setDefaults)
        .onDisappear {
            // Ignore the sheets opening on top of this screen; only clean up when really leaving.
            if review == nil && !showPicker { dropUnusedBrowsed(all: true) }
        }
    }

    // MARK: Cards

    private var payCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You pay").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                AssetMenu(selectedID: fromID, assets: wallet.assets) { id in
                    if id == toID { toID = fromID }
                    fromID = id
                }
                TextField("0", text: $payText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .focused($focused)
                    .accessibilityLabel("Pay amount")
                    .accessibilityIdentifier("swap_pay_amount")
            }
            HStack {
                if let from = fromAsset {
                    Text("Balance: \(wallet.settings.hideBalances ? "••••" : Format.quantity(from.quantity)) \(from.ticker)")
                }
                Spacer()
                Button("MAX") {
                    if let from = fromAsset {
                        Haptics.selection()
                        payText = Format.plain(from.quantity)
                    }
                }
                .font(.footnote.weight(.bold))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardStyle()
    }

    private var flipButton: some View {
        Button {
            Haptics.impact(.medium)
            withAnimation(.snappy) {
                let previous = fromID
                fromID = toID
                toID = previous
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppConfig.accent, in: Circle())
                .overlay(Circle().stroke(Color.appBackground, lineWidth: 4))
        }
        .padding(.vertical, -22)
        .zIndex(1)
        .accessibilityLabel("Flip assets")
    }

    private var receiveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You receive (estimated)").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Button {
                    Haptics.selection()
                    focused = false
                    showPicker = true
                } label: {
                    HStack(spacing: 8) {
                        if let toAsset {
                            TokenIcon(ticker: toAsset.ticker, colorHex: toAsset.colorHex,
                                      imageURL: toAsset.imageURL, size: 28)
                            Text(toAsset.ticker).font(.headline)
                        } else {
                            Text("Select").font(.headline)
                        }
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel("Choose asset to receive")
                Spacer()
                Text(quote.map { Format.quantity($0.receiveAmount) } ?? "0")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(quote == nil ? .secondary : .primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Estimated receive amount")
            }
            if let toAsset, let quote {
                Text(Format.usd(quote.receiveAmount * toAsset.price))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func detailsCard(_ q: SwapQuote) -> some View {
        VStack(spacing: 0) {
            KeyValueRow(key: "Rate", value: "1 \(q.fromTicker) ≈ \(Format.quantity(q.rate)) \(q.toTicker)")
            Divider().padding(.leading, 16)
            KeyValueRow(key: "Price impact", value: "\(q.priceImpactPercent.formatted(.number.precision(.fractionLength(2))))%",
                        valueColor: q.priceImpactPercent > 3 ? .orange : .primary)
            Divider().padding(.leading, 16)
            KeyValueRow(key: "Network fee", value: Format.usd(q.networkFeeUSD))
        }
        .cardStyle()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func pickReceiveAsset(_ asset: Asset) {
        setReceive(asset.id)
        dropUnusedBrowsed()
    }

    private func pickReceiveCoin(_ coin: MarketCoin) {
        let alreadyHeld = wallet.assets.contains { $0.coinID == coin.id }
        guard let id = try? wallet.ensureAsset(for: coin) else { return }
        if !alreadyHeld { browsedIDs.insert(id) }
        setReceive(id)
        dropUnusedBrowsed()
    }

    private func setReceive(_ id: Asset.ID) {
        if id == fromID { fromID = toID }
        toID = id
    }

    /// Removes coins that were only picked to look at and never swapped into.
    private func dropUnusedBrowsed(all: Bool = false) {
        for id in browsedIDs {
            if (wallet.asset(id: id)?.quantity ?? 0) > 0 {
                browsedIDs.remove(id)
                continue
            }
            if !all && (id == toID || id == fromID) { continue }
            wallet.discardEmptyAsset(id: id)
            browsedIDs.remove(id)
            if toID == id { toID = nil }
            if fromID == id { fromID = nil }
        }
    }

    private func setDefaults() {
        if fromID == nil {
            fromID = presetFrom ?? wallet.asset(ticker: "SOL")?.id ?? wallet.assets.first?.id
        }
        if toID == nil {
            toID = presetTo ?? wallet.asset(ticker: "USDC")?.id ?? wallet.assets.first { $0.id != fromID }?.id
        }
        if fromID == toID { toID = wallet.assets.first { $0.id != fromID }?.id }
    }
}

// MARK: - Review / confirmation

private struct ReviewItem: Identifiable {
    let id = UUID()
    let quote: SwapQuote
}

private struct ReviewSwapSheet: View {
    let quote: SwapQuote
    var onComplete: () -> Void

    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable { case review, processing, done, failed(String) }
    @State private var phase: Phase = .review

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch phase {
                case .done: success
                default: review
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.appBackground)
            .navigationTitle(phase == .done ? "" : "Review swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if phase != .done { Button("Cancel") { dismiss() }.disabled(phase == .processing) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(phase == .processing)
        .animation(.spring(duration: 0.4), value: phase)
    }

    private var review: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                KeyValueRow(key: "You pay", value: "\(Format.quantity(quote.payAmount)) \(quote.fromTicker)")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "You receive", value: "\(Format.quantity(quote.receiveAmount)) \(quote.toTicker)")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Rate", value: "1 \(quote.fromTicker) ≈ \(Format.quantity(quote.rate)) \(quote.toTicker)")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Price impact", value: "\(quote.priceImpactPercent.formatted(.number.precision(.fractionLength(2))))%")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Network fee", value: Format.usd(quote.networkFeeUSD))
            }
            .cardStyle()

            if case .failed(let message) = phase {
                Text(message).font(.footnote).foregroundStyle(.red)
            }

            Button {
                confirm()
            } label: {
                if phase == .processing {
                    ProgressView().tint(.white)
                } else {
                    Text("Confirm swap")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(phase == .processing)
            .accessibilityIdentifier("swap_confirm")
        }
    }

    private var success: some View {
        SwapSuccessView(quote: quote) { dismiss() }
    }

    private func confirm() {
        phase = .processing
        Haptics.impact(.medium)
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            do {
                _ = try wallet.executeSwap(quote)
                phase = .done
                onComplete()
            } catch {
                Haptics.error()
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Token picker (your assets + every market coin)

private struct TokenPickerSheet: View {
    let held: [Asset]
    let coins: [MarketCoin]
    var onPickAsset: (Asset) -> Void
    var onPickCoin: (MarketCoin) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    private func matches(_ name: String, _ ticker: String) -> Bool {
        query.isEmpty || name.localizedCaseInsensitiveContains(query) || ticker.localizedCaseInsensitiveContains(query)
    }

    private var heldMatches: [Asset] { held.filter { matches($0.name, $0.ticker) } }

    private var otherCoins: [MarketCoin] {
        let heldIDs = Set(held.compactMap(\.coinID))
        return coins.filter { $0.price > 0 && !heldIDs.contains($0.id) && matches($0.name, $0.ticker) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !heldMatches.isEmpty {
                    Section("Your assets") {
                        ForEach(heldMatches) { asset in
                            Button {
                                Haptics.selection()
                                onPickAsset(asset)
                                dismiss()
                            } label: {
                                row(name: asset.name, ticker: asset.ticker, colorHex: asset.colorHex, image: asset.imageURL)
                            }
                        }
                    }
                }
                Section("All coins (\(otherCoins.count))") {
                    ForEach(otherCoins) { coin in
                        Button {
                            Haptics.selection()
                            onPickCoin(coin)
                            dismiss()
                        } label: {
                            row(name: coin.name, ticker: coin.ticker, colorHex: coin.colorHex, image: coin.image)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Choose coin")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search coins")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func row(name: String, ticker: String, colorHex: String, image: String?) -> some View {
        HStack(spacing: 12) {
            TokenIcon(ticker: ticker, colorHex: colorHex, imageURL: image, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(ticker).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Success animation

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.54))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.28))
        return path
    }
}

private struct SwapSuccessView: View {
    let quote: SwapQuote
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var check: CGFloat = 0
    @State private var pop = false
    @State private var burstStarted = false
    @State private var burstOut = false
    @State private var showText = false

    private let burstCount = 8

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            ZStack {
                ForEach(0..<burstCount, id: \.self) { index in
                    let angle = Double(index) / Double(burstCount) * 2 * Double.pi
                    Text(index.isMultiple(of: 2) ? "💸" : "✨")
                        .font(.title2)
                        .offset(x: burstOut ? CGFloat(cos(angle)) * 100 : 0,
                                y: burstOut ? CGFloat(sin(angle)) * 100 : 0)
                        .scaleEffect(burstOut ? 1.1 : 0.3)
                        .opacity(burstStarted ? (burstOut ? 0 : 1) : 0)
                }

                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 112, height: 112)
                    .scaleEffect(pop ? 1 : 0.6)
                    .opacity(pop ? 1 : 0)

                Circle()
                    .trim(from: 0, to: ring)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 112, height: 112)

                CheckShape()
                    .trim(from: 0, to: check)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .frame(width: 56, height: 56)
            }
            .frame(width: 220, height: 220)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Swap complete")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("\(Format.quantity(quote.payAmount)) \(quote.fromTicker)  →  \(Format.quantity(quote.receiveAmount)) \(quote.toTicker)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppConfig.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(AppConfig.accent)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 14)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 16)

            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
        }
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            ring = 1; check = 1; pop = true; showText = true
            return
        }
        withAnimation(.easeOut(duration: 0.5)) { ring = 1 }
        try? await Task.sleep(for: .milliseconds(380))
        withAnimation(.spring(duration: 0.45, bounce: 0.5)) { pop = true }
        withAnimation(.easeOut(duration: 0.35)) { check = 1 }
        try? await Task.sleep(for: .milliseconds(300))
        burstStarted = true
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.easeOut(duration: 1.0)) { burstOut = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.1)) { showText = true }
    }
}
