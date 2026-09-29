import SwiftUI

struct SwapView: View {
    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    var presetFrom: Asset.ID? = nil
    var presetTo: Asset.ID? = nil
    var isSheet = false

    @State private var fromID: Asset.ID?
    @State private var toID: Asset.ID?
    @State private var payText = ""
    @State private var showReview = false
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
                        showReview = true
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
            .sheet(isPresented: $showReview) {
                if let quote { ReviewSwapSheet(quote: quote) { payText = "" } }
            }
        }
        .onAppear(perform: setDefaults)
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
                AssetMenu(selectedID: toID, assets: wallet.assets) { id in
                    if id == fromID { fromID = toID }
                    toID = id
                }
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
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: phase == .done)
                .padding(.top, 24)
            Text("Swap complete").font(.title2.weight(.bold))
            Text("\(Format.quantity(quote.payAmount)) \(quote.fromTicker) → \(Format.quantity(quote.receiveAmount)) \(quote.toTicker)")
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .transition(.scale.combined(with: .opacity))
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
