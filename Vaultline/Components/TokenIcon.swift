import SwiftUI

struct TokenIcon: View {
    let ticker: String
    let colorHex: String
    var imageURL: String? = nil
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: colorHex))
            letter
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().clipShape(Circle())
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var letter: some View {
        Text(String(ticker.prefix(1)))
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }
}
