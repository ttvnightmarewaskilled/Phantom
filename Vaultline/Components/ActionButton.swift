import SwiftUI

struct ActionButton: View {
    let title: String
    let symbol: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppConfig.accent, in: Circle())
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .cardStyle()
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityIdentifier("action_\(title.lowercased())")
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).foregroundStyle(valueColor).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct AssetMenu: View {
    let selectedID: Asset.ID?
    let assets: [Asset]
    let onPick: (Asset.ID) -> Void

    var body: some View {
        Menu {
            ForEach(assets) { asset in
                Button("\(asset.ticker) · \(asset.name)") {
                    Haptics.selection()
                    onPick(asset.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let asset = assets.first(where: { $0.id == selectedID }) {
                    TokenIcon(ticker: asset.ticker, colorHex: asset.colorHex, imageURL: asset.imageURL, size: 28)
                    Text(asset.ticker).font(.headline)
                } else {
                    Text("Select").font(.headline)
                }
                Image(systemName: "chevron.down").font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
        }
        .accessibilityLabel("Choose asset")
    }
}
