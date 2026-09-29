import SwiftUI

struct SettingsView: View {
    @Environment(WalletViewModel.self) private var wallet
    @Environment(PriceService.self) private var prices
    @State private var name = ""
    @State private var apiKey = ""
    @State private var toast: String?

    private func binding(_ keyPath: WritableKeyPath<WalletSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { wallet.settings[keyPath: keyPath] },
            set: { newValue in wallet.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Wallet") {
                    HStack {
                        LogoMark(size: 32)
                        TextField("Wallet name", text: $name)
                            .onSubmit { wallet.renameWallet(name) }
                            .submitLabel(.done)
                    }
                    Button {
                        UIPasteboard.general.string = wallet.address
                        Haptics.success()
                        toast = "Address copied"
                    } label: {
                        LabeledContent("Address") {
                            Text(wallet.address.shortAddress).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("Preferences") {
                    Toggle("Haptic feedback", isOn: binding(\.hapticsEnabled))
                    Toggle("Hide balances", isOn: binding(\.hideBalances))
                    Toggle("Show “Demo Mode” badge", isOn: binding(\.showDemoBadge))
                }

                Section {
                    Toggle("Live prices", isOn: Binding(
                        get: { wallet.settings.livePricesEnabled },
                        set: { enabled in
                            wallet.updateSettings { $0.livePricesEnabled = enabled }
                            if enabled {
                                Task {
                                    await prices.refresh(force: true, heldIDs: wallet.heldCoinIDs)
                                    wallet.applyLivePrices { prices.coin(id: $0) }
                                }
                            }
                        }
                    ))
                    TextField("CoinGecko Demo API key (optional)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { prices.setAPIKey(apiKey) }
                    if let updated = prices.lastUpdated {
                        LabeledContent("Last update") {
                            Text(updated, style: .relative).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Market data")
                } footer: {
                    Text("Prices come from CoinGecko's free public API. Assets you price by hand are never overwritten.")
                }

                Section {
                    Toggle("Developer tools", isOn: binding(\.developerModeEnabled))
                    if wallet.settings.developerModeEnabled {
                        NavigationLink("Demo controls") { DemoControlsView() }
                            .accessibilityIdentifier("open_demo_controls")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Edit assets, prices and transactions to test the app.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("\(AppConfig.appName) is an original demo app. Balances and trades are simulated and stored only on this device. It is not a real wallet and holds no real funds.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                name = wallet.walletName
                apiKey = prices.apiKey
            }
            .onDisappear {
                wallet.renameWallet(name)
                prices.setAPIKey(apiKey)
            }
            .toast($toast)
        }
    }
}
