import SwiftUI

struct SendView: View {
    var initialAssetID: Asset.ID? = nil

    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    enum Step { case form, review, done }
    @State private var step: Step = .form
    @State private var recipient = ""
    @State private var assetID: Asset.ID?
    @State private var amountText = ""
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var asset: Asset? { assetID.flatMap { wallet.asset(id: $0) } }
    private var cleanRecipient: String { recipient.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amount: Double { Format.parse(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch step {
                    case .form: form
                    case .review: review
                    case .done: done
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .navigationTitle(step == .done ? "" : "Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .done { Button("Close") { dismiss() } }
                }
            }
        }
        .animation(.snappy, value: step)
        .onAppear {
            if assetID == nil { assetID = initialAssetID ?? wallet.assets.first?.id }
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipient").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("Wallet address", text: $recipient, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .accessibilityIdentifier("send_recipient")
                    Button("Paste") {
                        if let text = UIPasteboard.general.string {
                            recipient = text
                            Haptics.selection()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .padding(16)
            .cardStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Amount").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    AssetMenu(selectedID: assetID, assets: wallet.assets) { assetID = $0 }
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .focused($focused)
                        .accessibilityLabel("Amount to send")
                        .accessibilityIdentifier("send_amount")
                }
                HStack {
                    if let asset {
                        Text("Balance: \(wallet.settings.hideBalances ? "••••" : Format.quantity(asset.quantity)) \(asset.ticker)")
                    }
                    Spacer()
                    Button("MAX") {
                        if let asset {
                            Haptics.selection()
                            amountText = Format.plain(asset.quantity)
                        }
                    }
                    .font(.footnote.weight(.bold))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                if let asset, amount > 0 {
                    Text("≈ \(Format.usd(amount * asset.price))").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .cardStyle()

            KeyValueRow(key: "Network fee", value: Format.usd(AppConfig.networkFeeUSD))
                .cardStyle()

            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(.red)
            }

            Button("Review") { validate() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("send_review")
        }
    }

    private func validate() {
        focused = false
        guard let asset else { return fail(WalletError.assetNotFound) }
        guard AddressTools.isValid(cleanRecipient) else { return fail(WalletError.invalidRecipient) }
        guard amount > 0 else { return fail(WalletError.invalidAmount) }
        guard amount <= asset.quantity else { return fail(WalletError.insufficientBalance) }
        errorText = nil
        Haptics.impact(.medium)
        step = .review
    }

    private func fail(_ error: WalletError) {
        errorText = error.localizedDescription
        Haptics.error()
    }

    // MARK: Review / done

    private var review: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                KeyValueRow(key: "Asset", value: asset?.name ?? "–")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Amount", value: "\(Format.quantity(amount)) \(asset?.ticker ?? "")")
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Value", value: Format.usd(amount * (asset?.price ?? 0)))
                Divider().padding(.leading, 16)
                KeyValueRow(key: "To", value: cleanRecipient.shortAddress)
                Divider().padding(.leading, 16)
                KeyValueRow(key: "Network fee", value: Format.usd(AppConfig.networkFeeUSD))
            }
            .cardStyle()

            Button("Confirm send") { confirm() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("send_confirm")
            Button("Edit") { step = .form }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func confirm() {
        guard let asset else { return }
        do {
            try wallet.send(assetID: asset.id, recipient: cleanRecipient, amount: amount)
            step = .done
        } catch {
            errorText = error.localizedDescription
            step = .form
            Haptics.error()
        }
    }

    private var done: some View {
        VStack(spacing: 14) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppConfig.accent)
                .symbolEffect(.bounce, value: step)
                .padding(.top, 40)
            Text("Sent").font(.title2.weight(.bold))
            Text("\(Format.quantity(amount)) \(asset?.ticker ?? "") to \(cleanRecipient.shortAddress)")
                .foregroundStyle(.secondary)
            Text("Pending — it will settle in a few seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 24)
        }
    }
}
