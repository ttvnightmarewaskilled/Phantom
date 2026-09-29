import SwiftUI

@main
struct VaultlineApp: App {
    @State private var wallet = WalletViewModel()
    @State private var prices = PriceService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wallet)
                .environment(prices)
                .tint(AppConfig.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { wallet.saveNow() }
        }
    }
}
