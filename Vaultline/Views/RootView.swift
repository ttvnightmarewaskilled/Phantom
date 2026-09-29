import SwiftUI

struct RootView: View {
    @Environment(WalletViewModel.self) private var wallet
    @Environment(PriceService.self) private var prices
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .home

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { item in
                content(for: item)
                    .opacity(tab == item ? 1 : 0)
                    .allowsHitTesting(tab == item)
                    .accessibilityHidden(tab != item)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigation(selection: $tab)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await pollPrices()
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView(openSettings: { withAnimation(.snappy) { self.tab = .settings } })
        case .swap: SwapView()
        case .activity: ActivityView()
        case .markets: MarketsView()
        case .settings: SettingsView()
        }
    }

    /// Refreshes market data about once a minute while the app is in the foreground.
    private func pollPrices() async {
        while !Task.isCancelled {
            await prices.refresh(heldIDs: wallet.heldCoinIDs)
            wallet.applyLivePrices { prices.coin(id: $0) }
            try? await Task.sleep(for: .seconds(60))
        }
    }
}
