# Vaultline (demo wallet, SwiftUI, iOS 17+)

An original, simulated crypto wallet. Balances and trades are fake and stored on the device only.
Market prices (Markets tab, live prices) come from CoinGecko's free public API.

## Build an installable .ipa with GitHub (no Mac needed)

1. Create a **public** GitHub repository (public repos get free macOS build minutes).
2. Upload everything in this folder to the repo root: `project.yml`, `Vaultline/`, `.github/`, `Config/`.
   - If the web uploader skips `.github`, use **Add file → Create new file**, type `.github/workflows/build.yml`, and paste the contents of that file.
3. Open the **Actions** tab, choose **Build unsigned IPA**, and click **Run workflow** (it also runs on every push).
4. When it finishes (about 5-10 minutes), open the run and download the **Vaultline-ipa** artifact. Unzip it to get `Vaultline.ipa`.
5. If the run fails, download the **build-log** artifact and send me the error lines.

## Install on your iPhone (Windows + AltStore)

1. Plug in the iPhone, make sure AltServer is running in the tray.
2. Right-click the AltServer tray icon, choose **Sideload .ipa**, pick `Vaultline.ipa` and your iPhone.
3. Refresh at least every 7 days: plug in, open AltStore, tap **Refresh All**.

## Project layout

- `Vaultline/Models` - Asset, Transaction, WalletState, MarketCoin
- `Vaultline/Services` - WalletStore (JSON persistence), PriceService (CoinGecko), ChartGenerator
- `Vaultline/ViewModels` - WalletViewModel (all wallet logic)
- `Vaultline/Components` - reusable views
- `Vaultline/Views` - screens

Developer tools: Settings -> turn on **Developer tools** -> **Demo controls**.
Rename or recolor the app in `Vaultline/Core/AppConfig.swift`.
