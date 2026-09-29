import Foundation
import os

/// JSON file persistence in Application Support. Works fully offline.
struct WalletStore {
    let fileURL: URL
    private static let log = Logger(subsystem: "com.vaultline.app", category: "store")

    init(fileName: String = "wallet_state.json") {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(fileName)
    }

    func load() -> WalletState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(WalletState.self, from: data)
        } catch {
            Self.log.error("Decode failed: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ state: WalletState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Self.log.error("Save failed: \(error.localizedDescription)")
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
