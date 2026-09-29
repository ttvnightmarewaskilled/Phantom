import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, swap, activity, markets, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .swap: "Swap"
        case .activity: "Activity"
        case .markets: "Markets"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .swap: "arrow.left.arrow.right"
        case .activity: "clock.fill"
        case .markets: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape.fill"
        }
    }
}

struct BottomNavigation: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.3)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.title3)
                        Text(tab.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selection == tab ? AppConfig.accent : Color.secondary)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(AppConfig.accent.opacity(0.12))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("tab_\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background(.bar)
    }
}
