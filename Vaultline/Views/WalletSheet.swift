import SwiftUI

enum WalletSheet: Identifiable {
    case send(Asset.ID?)
    case receive(Asset.ID?)
    case swap(from: Asset.ID?, to: Asset.ID?)

    var id: String {
        switch self {
        case .send(let id): return "send-\(id?.uuidString ?? "")"
        case .receive(let id): return "receive-\(id?.uuidString ?? "")"
        case .swap(let from, let to): return "swap-\(from?.uuidString ?? "")-\(to?.uuidString ?? "")"
        }
    }
}

struct WalletSheetView: View {
    let sheet: WalletSheet

    var body: some View {
        switch sheet {
        case .send(let id): SendView(initialAssetID: id)
        case .receive(let id): ReceiveView(initialAssetID: id)
        case .swap(let from, let to): SwapView(presetFrom: from, presetTo: to, isSheet: true)
        }
    }
}
