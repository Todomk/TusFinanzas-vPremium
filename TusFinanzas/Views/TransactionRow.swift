import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var showingEdit = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Binding var selectedTab: Int
    var navigateToGastosDiarios: Binding<Bool>? = nil
    var navigateToPropinas: Binding<Bool>? = nil
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    // Calcula la fecha del próximo cargo basado en el estado del ítem
    private func getNextChargeDate(transaction: Transaction) -> Date? {
        // Si la transacción ya tiene una fecha de próxima aparición calculada, usar esa
        if let nextAppearanceDate = transaction.nextAppearanceDate {
            return nextAppearanceDate
        }
        
        // Si no tiene fecha de próxima aparición calculada, calcularla
        guard let startDate = transaction.startDate else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Extraer el día del mes de la fecha de inicio
        let dayComponents = calendar.dateComponents([.day], from: startDate)
        let day = dayComponents.day ?? 1
        
        // Determinar si se debe mostrar el mes actual o el siguiente
        var targetDate: Date
        
        if transaction.isCompleted {
            // Para ítems completados, mostrar el mes siguiente
            var components = calendar.dateComponents([.year, .month], from: now)
            components.month = (components.month ?? 1) + 1  // Mes siguiente
            components.day = day
            
            // Si el día es mayor que el último día del mes, ajustar al último día
            if let date = calendar.date(from: components) {
                let range = calendar.range(of: .day, in: .month, for: date)
                if let maxDay = range?.count, day > maxDay {
                    components.day = maxDay
                }
            }
            
            targetDate = calendar.date(from: components) ?? now
        } else {
            // Para ítems pendientes, mostrar el mes actual
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = day
            
            // Si el día es mayor que el último día del mes, ajustar al último día
            if let date = calendar.date(from: components) {
                let range = calendar.range(of: .day, in: .month, for: date)
                if let maxDay = range?.count, day > maxDay {
                    components.day = maxDay
                }
            }
            
            targetDate = calendar.date(from: components) ?? now
        }
        
        return targetDate
    }
    
    private func formatNextAppearanceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if transaction.type != .tips && transaction.type != .gp {
            Button(action: {
                    let result = viewModel.toggleTransactionCompletion(transaction)
                    if !result.success, let message = result.message {
                        alertMessage = message
                        showAlert = true
                    }
                    
                    // Forzar actualización de la vista y recálculo de totales inmediatamente
                    if transaction.type == .income {
                        // Recalcular totales específicos de ingresos
                        viewModel.updateIncomeData()
                        
                        // Forzar redibujo completo de la vista
                        DispatchQueue.main.async {
                            viewModel.objectWillChange.send()
                        }
                    } else {
                        // Para otros tipos, actualizar después de un breve retraso
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            viewModel.objectWillChange.send()
                        }
                    }
            }) {
                Image(systemName: transaction.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(transaction.isCompleted ? .green : .gray)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Acción no permitida"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("Entendido"))
                    )
                }
            }
            
            Button(action: { 
                if transaction.type == .tips {
                    withAnimation {
                        selectedTab = 3 // Navegar a la pestaña Más
                        // Primero desactivamos para asegurar que se active correctamente después
                        navigateToPropinas?.wrappedValue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToPropinas?.wrappedValue = true
                        }
                    }
                } else if transaction.concept == "Gastos Diarios" {
                    withAnimation {
                        selectedTab = 3 // Navegar a la pestaña Más
                        // Primero desactivamos para asegurar que se active correctamente después
                        navigateToGastosDiarios?.wrappedValue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToGastosDiarios?.wrappedValue = true
                        }
                    }
                } else if transaction.concept == "Propinas" {
                    // Para la transacción representativa de Propinas en la lista de ingresos
                    withAnimation {
                        selectedTab = 3 // Navegar a la pestaña Más
                        // Primero desactivamos para asegurar que se active correctamente después
                        navigateToPropinas?.wrappedValue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToPropinas?.wrappedValue = true
                        }
                    }
                } else {
                    showingEdit = true
                }
            }) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.concept)
                            .font(.body)
                            .bold()
                            .foregroundColor(.primary)
                            .strikethrough(transaction.isCompleted && transaction.type != .tips)
                        
                        // Información general: Periodicidad + Tipo de pago + Método de pago + día
                        if transaction.type == .gp {
                            // Mostrar la categoría (estandard o personalizada)
                            if let customCategory = transaction.customGPCategory, !customCategory.isEmpty {
                                Text(customCategory)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else if let category = transaction.gpCategory {
                                Text(category.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                // Mostrar el método de pago (estandard o personalizado)
                                if let customMethod = transaction.customPaymentMethod, !customMethod.isEmpty {
                                    Text(customMethod)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(transaction.paymentMethod.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let date = transaction.startDate {
                                    Text("• \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if transaction.type != .tips {
                            // Primera línea: Periodicidad y tipo de pago
                            Text("\(transaction.periodicity.rawValue) • \(transaction.paymentType.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .strikethrough(transaction.isCompleted)
                                .lineLimit(1)
                            
                            // Segunda línea: Método de pago y día del mes
                            if let startDate = transaction.startDate {
                                let calendar = Calendar.current
                                let day = calendar.component(.day, from: startDate)
                                
                                Text("\(transaction.paymentMethod.rawValue) • Cada día: \(day)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .strikethrough(transaction.isCompleted)
                                    .lineLimit(1)
                            } else {
                                Text(transaction.paymentMethod.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .strikethrough(transaction.isCompleted)
                                    .lineLimit(1)
                            }
                            
                            // Mostrar fecha de próximo cargo para gastos y suscripciones
                            if transaction.type == .expense || transaction.type == .subscription {
                                if let nextChargeDate = transaction.nextAppearanceDate {
                                    Text("Próximo cargo: \(formatNextAppearanceDate(nextChargeDate))")
                                        .font(.caption2)
                                        .foregroundColor(transaction.isCompleted ? .blue : .orange)
                                        .italic()
                                } else if let nextChargeDate = getNextChargeDate(transaction: transaction) {
                                    Text("Próximo cargo: \(formatNextAppearanceDate(nextChargeDate))")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .italic()
                                } else {
                                    Text("Próximo cargo: pendiente")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            // Para periodicidad no mensual de otros tipos, mostrar Próximo cargo
                            else if transaction.periodicity != .monthly {
                                if let nextChargeDate = transaction.nextAppearanceDate {
                                    Text("Próximo cargo: \(formatNextAppearanceDate(nextChargeDate))")
                                        .font(.caption2)
                                        .foregroundColor(transaction.isCompleted ? .blue : .orange)
                                        .italic()
                                } else if let nextChargeDate = getNextChargeDate(transaction: transaction) {
                                    Text("Próximo cargo: \(formatNextAppearanceDate(nextChargeDate))")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .italic()
                                } else {
                                    Text("Próximo cargo: pendiente")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        } else if transaction.concept == "Propinas" {
                            // No mostrar ningún indicador visual para "Propinas" en ingresos
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.2f €", transaction.amount))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.yellow)
                            .strikethrough(transaction.isCompleted && transaction.type != .tips)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, transaction.type == .tips ? 28 : 0)
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingEdit) {
            if transaction.type == .gp {
                EditGPTransactionView(transaction: transaction)
            } else {
                EditTransactionView(transaction: transaction)
            }
        }
    }
} 