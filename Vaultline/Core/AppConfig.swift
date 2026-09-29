import SwiftUI

/// Single place to rename or re-theme the app.
enum AppConfig {
    static let appName = "Vaultline"
    static let accentHex = "#7C5CFF"
    static let demoBadgeText = "DEMO MODE"
    static let accent = Color(hex: accentHex)

    /// Simulated network fee shown in Swap/Send (USD). Display only.
    static let networkFeeUSD = 0.002
}
