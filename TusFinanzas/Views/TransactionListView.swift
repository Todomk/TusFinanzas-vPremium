import SwiftUI

// Extraer vistas individuales para reducir la complejidad
struct PendingTransactionsSection: View {
    var transactions: [Transaction]
    var type: TransactionType
    var title: String
    @Binding var selectedTab: Int
    var navigateToPropinas: Binding<Bool>?
    
    var body: some View {
        // Crea la sección de transacciones pendientes
        Section(header: Text("Pendientes")) {
            if transactions.isEmpty {
                Text(title == "Suscripciones" ? "No hay suscripciones pendientes" : "No hay nada pendiente de cobrar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(transactions) { transaction in
                    if type == .income && transaction.concept == "Propinas" {
                        Button(action: {
                            withAnimation {
                                selectedTab = 3 // Navegar a la pestaña Más
                                // Primero desactivamos para asegurar que se active correctamente después
                                navigateToPropinas?.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToPropinas?.wrappedValue = true
                                }
                            }
                        }) {
                            TransactionRow(transaction: transaction, selectedTab: Binding.constant(selectedTab))
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        TransactionRow(transaction: transaction, selectedTab: Binding.constant(selectedTab))
                    }
                }
            }
        }
    }
}

struct CompletedTransactionsSection: View {
    var transactions: [Transaction]
    var type: TransactionType
    @Binding var selectedTab: Int
    var navigateToPropinas: Binding<Bool>?
    
    var body: some View {
        // Crea la sección de transacciones completadas
        Section(header: Text("Completados")) {
            if transactions.isEmpty {
                Text("No hay transacciones completadas")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(transactions) { transaction in
                    if type == .income && transaction.concept == "Propinas" {
                        Button(action: {
                            withAnimation {
                                selectedTab = 3 // Navegar a la pestaña Más
                                // Primero desactivamos para asegurar que se active correctamente después
                                navigateToPropinas?.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToPropinas?.wrappedValue = true
                                }
                            }
                        }) {
                            TransactionRow(transaction: transaction, selectedTab: Binding.constant(selectedTab))
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        TransactionRow(transaction: transaction, selectedTab: Binding.constant(selectedTab))
                    }
                }
            }
        }
    }
}

struct TransactionListView: View {
    @Binding var transactions: [Transaction]
    let title: String
    var pendingTotal: Double?
    var completedTotal: Double?
    var total: Double?
    let type: TransactionType
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAddTransaction = false
    @Binding var selectedTab: Int
    var navigateToGastosDiarios: Binding<Bool>? = nil
    var navigateToPropinas: Binding<Bool>? = nil
    var navigateToSuscripciones: Binding<Bool>? = nil
    @State private var showingEditTransaction: Transaction? = nil
    @State private var showingEditGPTransaction = false
    @State private var showingEditStandardTransaction = false
    
    // Función para formatear fechas
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    // Función para preparar transacciones pendientes
    private func getPendingTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        // Determinar qué mes estamos mostrando (actual o siguiente)
        let referenceDate = viewModel.showNextMonth ? 
            calendar.date(byAdding: .month, value: 1, to: now)! : now
        
        // Obtener componentes de año y mes de la fecha de referencia
        let referenceComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        
        // Filtramos primero
        let filtered = transactions.filter { transaction in
            // Si ya está completado, no es pendiente
            if transaction.isCompleted {
                return false
            }
            
            // Caso 1: Verificar si la fecha de inicio está en el mes actual o antes
            if let startDate = transaction.startDate {
                return isInCurrentMonthOrBefore(date: startDate)
            }
            
            // Caso 2: Verificar si la fecha de próxima aparición es del mes actual
            if let nextDate = transaction.nextAppearanceDate {
                let nextDateComponents = calendar.dateComponents([.year, .month], from: nextDate)
                
                // Incluir en pendientes si la próxima aparición es del mes actual o anterior
                return nextDateComponents.year! < referenceComponents.year! || 
                      (nextDateComponents.year! == referenceComponents.year! && 
                       nextDateComponents.month! <= referenceComponents.month!)
            }
            
            // Por defecto, mostrar en pendientes
            return true
        }
        
        // Luego ordenamos
        return sortedTransactions(filtered)
    }
    
    // Función para preparar transacciones completadas
    private func getCompletedTransactions() -> [Transaction] {
        // Filtramos primero
        let filtered = transactions.filter { $0.isCompleted }
        // Luego ordenamos
        return sortedTransactions(filtered)
    }

    // Función helper para calcular pendientes
    private func calculatePendingTotal() -> Double {
        transactions.filter { 
            !$0.isCompleted && isInCurrentMonthOrBefore(date: $0.startDate)
        }.reduce(0) { $0 + $1.amount }
    }
    
    // Función helper para calcular completados
    private func calculateCompletedTotal() -> Double {
        transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
    }
    
    // Formatea la fecha de próxima aparición
    private func formatNextAppearanceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    // Calcula la fecha del próximo cargo basado en el estado del ítem
    private func getNextChargeDate(transaction: Transaction) -> Date? {
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
    
    // Obtiene las transacciones futuras que cumplen uno de estos criterios:
    // 1. Tienen periodicidad distinta a mensual y su próxima aparición está después del mes actual
    // 2. Tienen fecha de inicio en un mes futuro (no en el mes actual)
    private func getFutureTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        // Determinar qué mes estamos mostrando (actual o siguiente)
        let referenceDate = viewModel.showNextMonth ? 
            calendar.date(byAdding: .month, value: 1, to: now)! : now
        
        // Obtener el inicio y fin del mes de referencia
        var components = calendar.dateComponents([.year, .month], from: referenceDate)
        components.day = 1
        let startOfReferenceMonth = calendar.date(from: components)!
        
        let endOfReferenceMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfReferenceMonth)!
        
        // Calcular el inicio del mes siguiente al de referencia
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfReferenceMonth)!
        
        return transactions.filter { transaction in
            // Caso 1: Transacción con fecha de inicio en un mes futuro (después del mes de referencia)
            if let startDate = transaction.startDate {
                let startDateComponents = calendar.dateComponents([.year, .month], from: startDate)
                let referenceComponents = calendar.dateComponents([.year, .month], from: referenceDate)
                
                // Comparar año y mes para determinar si está en un mes posterior
                if startDateComponents.year! > referenceComponents.year! || 
                   (startDateComponents.year! == referenceComponents.year! && 
                    startDateComponents.month! > referenceComponents.month!) {
                    return true
                }
                
                // Si la fecha está en el mismo mes pero después de la fecha actual, NO la consideramos futura
                // Este es el cambio clave que asegura coherencia con el filtro de Pendientes
                return false
            }
            
            // Caso 2: Verificar si la próxima aparición está en un mes futuro
            if let nextDate = transaction.nextAppearanceDate {
                let nextDateComponents = calendar.dateComponents([.year, .month], from: nextDate)
                let referenceComponents = calendar.dateComponents([.year, .month], from: referenceDate)
                
                // Si el año es mayor O el año es igual pero el mes es mayor
                return nextDateComponents.year! > referenceComponents.year! || 
                      (nextDateComponents.year! == referenceComponents.year! && 
                       nextDateComponents.month! > referenceComponents.month!)
            }
            
            return false
        }.sorted { (t1, t2) -> Bool in
            // Ordenar primero por fecha de inicio (si existe)
            if let start1 = t1.startDate, let start2 = t2.startDate {
                return start1 < start2
            }
            // Si no hay fecha de inicio, ordenar por fecha de próxima aparición
            else if let date1 = t1.nextAppearanceDate, let date2 = t2.nextAppearanceDate {
                return date1 < date2
            }
            return false
        }
    }
    
    // Devuelve un icono adecuado según el tipo de transacción
    private func getIconForFutureTransaction(_ transaction: Transaction) -> String {
        switch transaction.type {
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        case .subscription:
            return "bell.circle.fill"
        case .tips:
            return "dollarsign.circle.fill"
        case .gp:
            return "cart.circle.fill"
        }
    }
    
    // Ordena las transacciones según criterios específicos
    private func sortedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        // Para suscripciones y gastos, ordenar por fecha de próximo cargo
        if type == .subscription || type == .expense {
            return transactions.sorted { t1, t2 in
                // Calcular las fechas de próximo cargo para ambas transacciones
                let date1 = getNextChargeDate(transaction: t1)
                let date2 = getNextChargeDate(transaction: t2)
                
                // Si ambas tienen fecha de próximo cargo, comparar por fecha
                if let d1 = date1, let d2 = date2 {
                    return d1 < d2
                }
                
                // Si solo una tiene fecha, la que tiene fecha va primero
                if date1 != nil {
                    return true
                }
                if date2 != nil {
                    return false
                }
                
                // Si ninguna tiene fecha, mantener el orden original
                return false
            }
        }
        
        // Para otros tipos, mantener orden original
        return transactions
    }
    
    // Función auxiliar para determinar si una fecha está en el mes actual o anterior
    private func isInCurrentMonthOrBefore(date: Date?) -> Bool {
        // Si no hay fecha, siempre mostrar
        guard let startDate = date else {
            return true
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Determinar qué mes estamos mostrando (actual o siguiente)
        let referenceDate = viewModel.showNextMonth ? 
            calendar.date(byAdding: .month, value: 1, to: now)! : now
        
        // Obtener los componentes de año y mes de ambas fechas
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let referenceComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        
        // La fecha está en un mes futuro si el año es mayor, o si el año es igual pero el mes es mayor
        let isInFutureMonth = startComponents.year! > referenceComponents.year! || 
                             (startComponents.year! == referenceComponents.year! && 
                              startComponents.month! > referenceComponents.month!)
        
        // Retornar verdadero si la fecha no está en un mes futuro
        return !isInFutureMonth
    }
    
    // Vista para mostrar el total pendiente de ingresos
    private func pendingIncomeTotal() -> some View {
        let visiblePendingIncome = calculatePendingTotal()
        
        return HStack {
            Text("Total pendiente")
            Spacer()
            Text(String(format: "%.2f €", visiblePendingIncome))
                .font(.title3)
                .bold()
                .foregroundColor(.red)
        }
    }
    
    // Vista para mostrar el total cobrado de ingresos
    private func completedIncomeTotal() -> some View {
        let completedSum = calculateCompletedTotal()
        
        return HStack {
            Text("Total cobrado")
            Spacer()
            Text(String(format: "%.2f €", completedSum))
                .font(.title3)
                .bold()
                .foregroundColor(.green)
        }
    }
    
    // Vista para mostrar el total general de ingresos
    private func totalIncomeSection() -> some View {
        let totalPendiente = calculatePendingTotal()
        let totalCobrado = calculateCompletedTotal()
        
        // Verificar si se deben mostrar las propinas
        let showTips = UserDefaults.standard.bool(forKey: "showTips")
        let foundTipsTransaction = viewModel.findTipsTransaction()
        
        // Calcular total de propinas si corresponde
        let totalPropinas: Double
        if showTips && foundTipsTransaction != nil {
            totalPropinas = viewModel.getCurrentMonthTipsTotal(tipTransaction: foundTipsTransaction!)
        } else {
            totalPropinas = 0
        }
        
        // Calcular el total general
        let granTotal = totalPendiente + totalCobrado + totalPropinas
        
        return VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.2f €", granTotal))
                .font(.title3)
                .bold()
                .foregroundColor(Color.blue.opacity(0.7))
            
            if showTips {
                Text("Pend: \(String(format: "%.2f", totalPendiente))€ + Cobr: \(String(format: "%.2f", totalCobrado))€ + Prop: \(String(format: "%.2f", totalPropinas))€")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Pend: \(String(format: "%.2f", totalPendiente))€ + Cobr: \(String(format: "%.2f", totalCobrado))€")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var body: some View {
        List {
            // Sección de pendientes extraída a una vista separada
            PendingTransactionsSection(
                transactions: getPendingTransactions(),
                type: type,
                title: title,
                selectedTab: $selectedTab,
                navigateToPropinas: navigateToPropinas
            )
            
            // Total pendiente
            if let _ = pendingTotal {
                Section {
                    if type == .income {
                        pendingIncomeTotal()
                    } else {
                        // Para gastos, implementación existente
                        if title == "Gastos de otras cuentas" {
                            let pendingSum = calculatePendingTotal()
                            HStack {
                                Text("Total pendiente")
                                Spacer()
                                Text(String(format: "%.2f €", pendingSum))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        } else {
                            // Implementación para otros casos
                            let pendingSum = calculatePendingTotal()
                            HStack {
                                Text("Total pendiente")
                                Spacer()
                                Text(String(format: "%.2f €", pendingSum))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // Sección de completados extraída a una vista separada
            CompletedTransactionsSection(
                transactions: getCompletedTransactions(),
                type: type,
                selectedTab: $selectedTab,
                navigateToPropinas: navigateToPropinas
            )
            
            // Total completado
            if let _ = completedTotal {
                Section {
                    if type == .income {
                        completedIncomeTotal()
                    } else {
                        // Para gastos, implementación existente
                        let completedSum = calculateCompletedTotal()
                        HStack {
                            Text(type == .income ? "Total cobrado" : "Total pagado")
                            Spacer()
                            Text(String(format: "%.2f €", completedSum))
                                .font(.title3)
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // Sección de propinas (solo para ingresos y si showTips está activado)
            if type == .income && UserDefaults.standard.bool(forKey: "showTips") {
                if let tipsTransaction = viewModel.findTipsTransaction() {
                    let tipTotal = viewModel.getCurrentMonthTipsTotal(tipTransaction: tipsTransaction)
                    Section {
                        HStack {
                            Text("Propinas")
                            Spacer()
                            Text(String(format: "%.2f €", tipTotal))
                                .font(.title3)
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Total general
            if let _ = total {
                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        if type == .income {
                            totalIncomeSection()
                        } else if type == .expense {
                            // Para gastos, calcular como suma de pendiente + pagado
                            // Asegurarse de incluir todos los componentes igual que en el widget
                            let pendingExpenses = calculatePendingTotal()
                            let completedExpenses = calculateCompletedTotal()
                            
                            // No incluimos gastos diarios ni suscripciones porque ya está incluido en el cálculo
                            // del total desde el viewModel en los casos donde este componente se usa para
                            // mostrar los gastos generales
                            let totalGastos = pendingExpenses + completedExpenses
                            
                            // Mostrar el total con un desglose
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f €", totalGastos))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Color.blue.opacity(0.7))
                                
                                Text("Pend: \(String(format: "%.2f", pendingExpenses))€ + Pagado: \(String(format: "%.2f", completedExpenses))€")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Para otros tipos (como suscripciones)
                            Text(String(format: "%.2f €", pendingTotal! + completedTotal!))
                                .font(.title3)
                                .bold()
                                .foregroundColor(Color.blue.opacity(0.7))
                        }
                    }
                }
            }
            
            // Eventos futuros
            let futureTransactions = getFutureTransactions()
            if !futureTransactions.isEmpty {
                Section(header: Text("Eventos de meses futuros").foregroundColor(Color.gray)) {
                    ForEach(futureTransactions) { transaction in
                        Button(action: {
                            showingEditTransaction = transaction
                            if transaction.type == .gp {
                                showingEditGPTransaction = true
                            } else {
                                showingEditStandardTransaction = true
                            }
                        }) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: getIconForFutureTransaction(transaction))
                                        .foregroundColor(Color.gray)
                                        .frame(width: 24, height: 24)
                                    Text(transaction.concept)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(String(format: "%.2f €", transaction.amount))
                                        .foregroundColor(Color.gray)
                                }
                                
                                // Primera línea adicional: Periodicidad + método de pago
                                Text("\(transaction.periodicity.rawValue) • \(transaction.paymentMethod.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 28)
                                
                                // Segunda línea adicional: Fecha de próxima aparición
                                if let nextDate = transaction.nextAppearanceDate {
                                    Text("Próxima aparición: \(formatDate(nextDate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 28)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
            if type == .gp {
                AddGPTransactionView()
            } else {
                AddTransactionView(type: type)
            }
        }
        .sheet(isPresented: $showingEditGPTransaction) {
            if let transaction = showingEditTransaction {
                EditGPTransactionView(transaction: transaction)
            }
        }
        .sheet(isPresented: $showingEditStandardTransaction) {
            if let transaction = showingEditTransaction {
                EditTransactionView(transaction: transaction)
            }
        }
    }
}
