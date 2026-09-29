import SwiftUI

struct TransactionRow: View {
    let tx: Transaction
    var hidden = false

    private var title: String {
        if tx.kind == .swapped { return "Swapped \(tx.ticker) → \(tx.secondaryTicker ?? "?")" }
        return "\(tx.kind.title) \(tx.ticker)"
    }

    private var amountText: String {
        let qty = Format.quantity(tx.amount)
        switch tx.kind {
        case .received: return "+\(qty) \(tx.ticker)"
        case .sent: return "-\(qty) \(tx.ticker)"
        case .swapped: return "+\(Format.quantity(tx.secondaryAmount ?? 0)) \(tx.secondaryTicker ?? "")"
        }
    }

    private var tint: Color {
        switch tx.kind {
        case .received: .green
        case .sent: .orange
        case .swapped: AppConfig.accent
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tx.kind.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                    StatusPill(status: tx.status)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(hidden ? "••••" : amountText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tx.kind == .received || tx.kind == .swapped ? Color.green : Color.primary)
                Text(hidden ? "••" : Format.usd(tx.usdValue))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct StatusPill: View {
    let status: TransactionStatus

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(status == .pending ? Color.orange : Color.secondary)
            .background((status == .pending ? Color.orange : Color.secondary).opacity(0.15), in: Capsule())
    }
}
