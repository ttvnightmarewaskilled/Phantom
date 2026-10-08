import SwiftUI

struct HomeView: View {
    @Environment(WalletViewModel.self) private var wallet
    var openSettings: () -> Void = {}

    @State private var sheet: WalletSheet?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PortfolioHeader(total: wallet.totalValue, change: wallet.change24hUSD,
                                    percent: wallet.change24hPercent, hidden: wallet.settings.hideBalances)

                    PeriodChart(
                        coinID: nil,
                        simulated: { wallet.portfolioSeries($0) },
                        format: { wallet.settings.hideBalances ? "••••" : Format.usd($0) },
                        showSourceLabel: false
                    )

                    HStack(spacing: 10) {
                        ActionButton(title: "Send", symbol: "arrow.up") { sheet = .send(nil) }
                        ActionButton(title: "Receive", symbol: "arrow.down") { sheet = .receive(nil) }
                        ActionButton(title: "Swap", symbol: "arrow.left.arrow.right") { sheet = .swap(from: nil, to: nil) }
                    }

                    assetsSection

                    Text("Simulated history · no real funds")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .background(Color.appBackground)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Asset.ID.self) { AssetDetailView(assetID: $0) }
        }
        .sheet(item: $sheet) { WalletSheetView(sheet: $0) }
        .toast($toast)
    }

    private var header: some View {
        HStack(spacing: 10) {
            LogoMark(size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(wallet.walletName).font(.headline)
                Button {
                    UIPasteboard.general.string = wallet.address
                    Haptics.success()
                    toast = "Address copied"
                } label: {
                    Label(wallet.address.shortAddress, systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Copy wallet address")
                .accessibilityIdentifier("copy_address")
            }
            Spacer()
            if wallet.settings.showDemoBadge { DemoBadge() }
            Button {
                Haptics.impact()
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.cardBackground))
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("open_settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Only assets you actually hold; anything at a zero balance is hidden here.
    private var heldAssets: [Asset] { wallet.assets.filter { $0.quantity > 0 } }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assets").font(.title3.weight(.semibold))
            if heldAssets.isEmpty {
                ContentUnavailableView("No assets", systemImage: "tray",
                                       description: Text("Add assets from Settings → Demo controls, or buy one in Markets."))
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(heldAssets.enumerated()), id: \.element.id) { index, asset in
                        NavigationLink(value: asset.id) {
                            AssetRow(asset: asset, hidden: wallet.settings.hideBalances)
                        }
                        .buttonStyle(PressableStyle())
                        .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                        .accessibilityIdentifier("asset_row_\(asset.ticker)")
                        if index < heldAssets.count - 1 { Divider().padding(.leading, 68) }
                    }
                }
                .cardStyle()
            }
        }
    }
}
