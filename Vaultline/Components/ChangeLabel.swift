import SwiftUI

struct ChangeLabel: View {
    let percent: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: percent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8))
            Text(Format.plainPercent(percent))
        }
        .foregroundStyle(Color.trend(percent))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent >= 0 ? "Up" : "Down") \(Format.plainPercent(percent))")
    }
}
