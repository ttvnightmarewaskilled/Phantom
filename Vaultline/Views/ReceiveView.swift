import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView: View {
    var initialAssetID: Asset.ID? = nil

    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var assetID: Asset.ID?
    @State private var toast: String?

    private var asset: Asset? { assetID.flatMap { wallet.asset(id: $0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AssetMenu(selectedID: assetID, assets: wallet.assets) { assetID = $0 }

                    Text("Receive \(asset?.ticker ?? "crypto")")
                        .font(.title3.weight(.semibold))

                    if let image = Self.qrImage(for: wallet.address) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityLabel("QR code for your wallet address")
                    }

                    Text(wallet.address)
                        .font(.system(.footnote, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .accessibilityIdentifier("receive_address")

                    Button {
                        UIPasteboard.general.string = wallet.address
                        Haptics.success()
                        toast = "Address copied"
                    } label: {
                        Label("Copy address", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("receive_copy")

                    ShareLink(item: wallet.address) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("This is a demo wallet. The address is simulated, so don't send real crypto to it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .toast($toast)
        }
        .onAppear {
            if assetID == nil { assetID = initialAssetID ?? wallet.assets.first?.id }
        }
    }

    private static func qrImage(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
