import SwiftUI

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "All", received = "Received", sent = "Sent", swapped = "Swapped", pending = "Pending"
    var id: String { rawValue }

    func matches(_ tx: Transaction) -> Bool {
        switch self {
        case .all: return true
        case .received: return tx.kind == .received
        case .sent: return tx.kind == .sent
        case .swapped: return tx.kind == .swapped
        case .pending: return tx.status == .pending
        }
    }
}

struct ActivityView: View {
    @Environment(WalletViewModel.self) private var wallet
    @State private var filter: ActivityFilter = .all

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [Transaction]
        var id: Date { day }
    }

    private var groups: [DayGroup] {
        let filtered = wallet.transactions.filter(filter.matches)
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: (grouped[day] ?? []).sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chips
                    if groups.isEmpty {
                        ContentUnavailableView("No transactions", systemImage: "clock",
                                               description: Text("Nothing matches this filter."))
                            .cardStyle()
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title(for: group.day)).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, tx in
                                    NavigationLink(value: tx.id) {
                                        TransactionRow(tx: tx, hidden: wallet.settings.hideBalances)
                                    }
                                    .buttonStyle(PressableStyle())
                                    .simultaneousGesture(TapGesture().onEnded { Haptics.selection() })
                                    if index < group.items.count - 1 { Divider().padding(.leading, 68) }
                                }
                            }
                            .cardStyle()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.snappy, value: filter)
            }
            .background(Color.appBackground)
            .navigationTitle("Activity")
            .navigationDestination(for: Transaction.ID.self) { TransactionDetailView(txID: $0) }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityFilter.allCases) { item in
                    Button {
                        Haptics.selection()
                        filter = item
                    } label: {
                        Text(item.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(filter == item ? Color.white : Color.primary)
                            .background(filter == item ? AppConfig.accent : Color.cardBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == item ? .isSelected : [])
                }
            }
        }
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
