import SwiftUI

struct DemoControlsView: View {
    @Environment(WalletViewModel.self) private var wallet
    @State private var editing: Asset?
    @State private var showAddAsset = false
    @State private var showNewTransaction = false
    @State private var confirmReset = false

    var body: some View {
        List {
            Section {
                ForEach(wallet.assets) { asset in
                    Button { editing = asset } label: {
                        HStack(spacing: 12) {
                            TokenIcon(ticker: asset.ticker, colorHex: asset.colorHex, imageURL: asset.imageURL, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(asset.name) · \(asset.ticker)").foregroundStyle(.primary)
                                Text("\(Format.quantity(asset.quantity)) × \(Format.price(asset.price)) · \(Format.percent(asset.change24h))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { wallet.assets[$0].id }
                    ids.forEach { wallet.removeAsset(id: $0) }
                }
                Button("Add asset", systemImage: "plus") { showAddAsset = true }
                    .accessibilityIdentifier("demo_add_asset")
            } header: {
                Text("Assets")
            } footer: {
                Text("Changes update the balance, charts and lists right away. Swipe to remove.")
            }

            Section("Transactions") {
                Button("Create transaction", systemImage: "plus") { showNewTransaction = true }
                    .accessibilityIdentifier("demo_new_transaction")
                let recent = Array(wallet.transactions.prefix(8))
                ForEach(recent) { tx in
                    TransactionRow(tx: tx).listRowInsets(EdgeInsets())
                }
                .onDelete { offsets in
                    offsets.map { recent[$0].id }.forEach { wallet.deleteTransaction(id: $0) }
                }
            }

            Section {
                Button("Reset demo data", role: .destructive) { confirmReset = true }
                    .accessibilityIdentifier("demo_reset")
            } footer: {
                Text("Restores the starting assets and transactions. Your settings are kept.")
            }
        }
        .navigationTitle("Demo controls")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { AssetEditorView(asset: $0) }
        .sheet(isPresented: $showAddAsset) { AssetEditorView(asset: nil) }
        .sheet(isPresented: $showNewTransaction) { NewTransactionView() }
        .confirmationDialog("Reset demo data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { wallet.resetDemoData() }
        } message: {
            Text("This replaces all assets and transactions with the defaults.")
        }
    }
}

struct AssetEditorView: View {
    let asset: Asset?

    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var ticker: String
    @State private var quantity: String
    @State private var price: String
    @State private var change: String
    @State private var errorText: String?

    init(asset: Asset?) {
        self.asset = asset
        _name = State(initialValue: asset?.name ?? "")
        _ticker = State(initialValue: asset?.ticker ?? "")
        _quantity = State(initialValue: Format.plain(asset?.quantity ?? 0))
        _price = State(initialValue: Format.plain(asset?.price ?? 0))
        _change = State(initialValue: Format.plain(asset?.change24h ?? 0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Token") {
                    TextField("Name", text: $name)
                    TextField("Ticker", text: $ticker)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("Values") {
                    LabeledContent("Quantity") {
                        TextField("0", text: $quantity).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Price (USD)") {
                        TextField("0", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("24h change (%)") {
                        TextField("0", text: $change).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
                if let asset {
                    Section {
                        Button("Remove asset", role: .destructive) {
                            wallet.removeAsset(id: asset.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(asset == nil ? "Add asset" : "Edit asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        guard let q = Format.parse(quantity), let p = Format.parse(price), let c = Format.parse(change) else {
            errorText = "Enter valid numbers."
            Haptics.error()
            return
        }
        do {
            if var existing = asset {
                existing.name = name
                existing.ticker = ticker
                existing.quantity = q
                existing.price = p
                existing.change24h = c
                try wallet.updateAsset(existing)
            } else {
                try wallet.addAsset(name: name, ticker: ticker, quantity: q, price: p, change24h: c)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }
}

struct NewTransactionView: View {
    @Environment(WalletViewModel.self) private var wallet
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TransactionKind = .received
    @State private var status: TransactionStatus = .completed
    @State private var ticker = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var applyToBalance = true
    @State private var secondTicker = ""
    @State private var secondAmount = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(TransactionStatus.allCases) { Text($0.title).tag($0) }
                    }
                    DatePicker("Date", selection: $date)
                }
                Section(kind == .swapped ? "Paid" : "Asset") {
                    Picker("Asset", selection: $ticker) {
                        ForEach(wallet.assets) { Text($0.ticker).tag($0.ticker) }
                    }
                    LabeledContent("Amount") {
                        TextField("0", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                if kind == .swapped {
                    Section("Received") {
                        Picker("Asset", selection: $secondTicker) {
                            ForEach(wallet.assets) { Text($0.ticker).tag($0.ticker) }
                        }
                        LabeledContent("Amount") {
                            TextField("0", text: $secondAmount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    Section {
                        Toggle("Apply to balance", isOn: $applyToBalance)
                    } footer: {
                        Text("When on, a received transaction adds to the balance and a sent one subtracts from it.")
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create", action: create) }
            }
            .onAppear {
                if ticker.isEmpty { ticker = wallet.assets.first?.ticker ?? "" }
                if secondTicker.isEmpty { secondTicker = wallet.assets.dropFirst().first?.ticker ?? ticker }
            }
        }
    }

    private func create() {
        guard let value = Format.parse(amount) else {
            errorText = "Enter a valid amount."
            Haptics.error()
            return
        }
        do {
            try wallet.createTransaction(
                kind: kind, status: status, ticker: ticker, amount: value, date: date,
                secondaryTicker: kind == .swapped ? secondTicker : nil,
                secondaryAmount: kind == .swapped ? Format.parse(secondAmount) : nil,
                applyToBalance: kind != .swapped && applyToBalance
            )
            dismiss()
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }
}
