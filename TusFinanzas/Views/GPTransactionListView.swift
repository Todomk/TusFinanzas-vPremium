import SwiftUI

struct GPTransactionListView: View {
    @Binding var transactions: [Transaction]
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var showingAddTransaction = false
    @Binding var selectedTab: Int
    
    private func formatCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date()).uppercased()
    }
    
    private func formatCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        List {
            ForEach(transactions.sorted(by: { ($0.startDate ?? Date()) > ($1.startDate ?? Date()) })) { transaction in
                TransactionRow(transaction: transaction, selectedTab: $selectedTab)
            }
            
            if !transactions.isEmpty {
                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(String(format: "%.2f €", transactions.reduce(0) { $0 + $1.amount }))
                            .font(.title3)
                            .bold()
                            .foregroundColor(Color.blue.opacity(0.7))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Gastos diarios")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Text("\(formatCurrentMonth()) \(formatCurrentYear())")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddTransaction = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(7)
                        .background(Color.yellow)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddGPTransactionView(externalIsPresented: $showingAddTransaction)
        }
    }
}