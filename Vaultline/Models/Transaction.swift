import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case received, sent, swapped
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbolName: String {
        switch self {
        case .received: "arrow.down.left"
        case .sent: "arrow.up.right"
        case .swapped: "arrow.left.arrow.right"
        }
    }
}

enum TransactionStatus: String, Codable, CaseIterable, Identifiable {
    case pending, completed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Transaction: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var kind: TransactionKind
    var status: TransactionStatus
    /// Token being received / sent / paid (for swaps).
    var ticker: String
    var amount: Double
    var usdValue: Double
    var date: Date
    /// Address of the other party, or "Swap".
    var counterparty: String
    var feeUSD: Double
    /// Swaps only: the asset received.
    var secondaryTicker: String?
    var secondaryAmount: Double?
    var signature: String
}
