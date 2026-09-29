import SwiftUI

struct TransactionDetailView: View {
    let txID: Transaction.ID
    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?

    var body: some View {
        Group {
            if let tx = wallet.transaction(id: txID) {
                content(tx)
            } else {
                ContentUnavailableView("Transaction not found", systemImage: "questionmark.circle")
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private func content(_ tx: Transaction) -> some View {
        let hidden = wallet.settings.hideBalances
        let swap = tx.kind == .swapped
        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: tx.kind.symbolName)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AppConfig.accent)
                        .frame(width: 64, height: 64)
                        .background(AppConfig.accent.opacity(0.15), in: Circle())
                    Text(tx.kind.title).font(.title3.weight(.semibold))
                    Text(hidden ? "••••" : "\(tx.kind == .received ? "+" : "-")\(Format.quantity(tx.amount)) \(tx.ticker)")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(hidden ? "••" : Format.usd(tx.usdValue)).foregroundStyle(.secondary)
                    StatusPill(status: tx.status)
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: 0) {
                    KeyValueRow(key: "Status", value: tx.status.title)
                    Divider().padding(.leading, 16)
                    if swap, let t2 = tx.secondaryTicker, let a2 = tx.secondaryAmount {
                        KeyValueRow(key: "Received", value: hidden ? "••••" : "\(Format.quantity(a2)) \(t2)")
                    } else {
                        KeyValueRow(key: tx.kind == .received ? "From" : "To", value: tx.counterparty.shortAddress)
                    }
                    Divider().padding(.leading, 16)
                    KeyValueRow(key: "Date", value: tx.date.formatted(date: .abbreviated, time: .shortened))
                    Divider().padding(.leading, 16)
                    KeyValueRow(key: "Network fee", value: Format.usd(tx.feeUSD))
                    Divider().padding(.leading, 16)
                    KeyValueRow(key: "Signature", value: tx.signature.shortAddress)
                }
                .cardStyle()

                Button {
                    UIPasteboard.general.string = tx.signature
                    Haptics.success()
                    toast = "Signature copied"
                } label: {
                    Label("Copy signature", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())

                if wallet.settings.developerModeEnabled {
                    Button("Delete transaction") {
                        wallet.deleteTransaction(id: tx.id)
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle(destructive: true))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}
