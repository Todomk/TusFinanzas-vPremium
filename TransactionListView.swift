import SwiftUI

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
            
            // Caso 2: Transacción con periodicidad distinta a mensual y próxima aparición después del mes de referencia
            if transaction.periodicity != .monthly, 
               let nextDate = transaction.nextAppearanceDate,
               nextDate >= startOfNextMonth {  // Usar >= para asegurar que esté en un mes posterior
                return true
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
    
    var body: some View {
        List {
            Section(header: Text("Pendientes")) {
                ForEach(sortedTransactions(transactions.filter { transaction in
                    // Solo mostrar como pendientes aquellas que:
                    // 1. No están completadas
                    // 2. Para transacciones con fecha de inicio:
                    //    - Si la fecha está en el mes actual o anterior, mostrarla
                    //    - Si la fecha está en un mes posterior, no mostrarla
                    !transaction.isCompleted &&
                    isInCurrentMonthOrBefore(date: transaction.startDate)
                })) { transaction in
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
                            TransactionRow(transaction: transaction, selectedTab: $selectedTab)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        TransactionRow(transaction: transaction, selectedTab: $selectedTab)
                    }
                }
                
                // Mensaje cuando no hay transacciones pendientes
                if transactions.filter { transaction in
                    !transaction.isCompleted && 
                    isInCurrentMonthOrBefore(date: transaction.startDate)
                }.isEmpty {
                    Text("No hay transacciones pendientes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            
            if let pendingTotal = pendingTotal {
                if type == .expense && title == "Gastos" {
                    Section {
                        Button(action: {
                            withAnimation {
                                selectedTab = 3 // Navegar a la pestaña Más
                                // Primero desactivamos para asegurar que se active correctamente después
                                navigateToSuscripciones?.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToSuscripciones?.wrappedValue = true
                                }
                            }
                        }) {
                            HStack {
                                Text("Gastos pendientes de otras cuentas")
                                Spacer()
                                HStack {
                                    Text(String(format: "%.2f €", viewModel.pendingSubscriptions))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.red)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section {
                    HStack {
                        Text("Total pendiente")
                        Spacer()
                        if type == .expense {
                            if title == "Gastos de otras cuentas" {
                                // Calcular el total de gastos de otras cuentas pendientes visibles
                                let pendingSum = transactions.filter { transaction in
                                    !transaction.isCompleted && 
                                    isInCurrentMonthOrBefore(date: transaction.startDate)
                                }.reduce(0) { $0 + $1.amount }
                                Text(String(format: "%.2f €", pendingSum))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.red)
                            } else if title == "Gastos" {
                                // Calcular el total de gastos pendientes visibles
                                let gastosPendientes = transactions.filter { transaction in
                                    !transaction.isCompleted && 
                                    isInCurrentMonthOrBefore(date: transaction.startDate)
                                }.reduce(0) { $0 + $1.amount }
                                
                                // Solo incluir gastos de otras cuentas pendientes no futuros
                                let suscripcionesPendientes = viewModel.pendingSubscriptions
                                let totalPendiente = gastosPendientes + suscripcionesPendientes
                                
                                // Mostrar desglose para ayudar al diagnóstico
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.2f €", totalPendiente))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.red)
                                    
                                    Text("Gastos: \(String(format: "%.2f", gastosPendientes))€ + GPO: \(String(format: "%.2f", suscripcionesPendientes))€")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                let pendingExpensesSum = transactions.filter { transaction in 
                                    !transaction.isCompleted && 
                                    isInCurrentMonthOrBefore(date: transaction.startDate) &&
                                    transaction.concept != "Gastos de otras cuentas"
                                }.reduce(0) { $0 + $1.amount }
                                
                                let pendingSubscriptionsTotal = viewModel.pendingSubscriptions
                                
                                let totalPending = pendingExpensesSum + pendingSubscriptionsTotal
                                Text(String(format: "%.2f €", totalPending))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        } else {
                            // Para ingresos, solo incluir los no futuros (utilizando la misma nueva lógica)
                            let visiblePendingIncome = transactions.filter { transaction in
                                !transaction.isCompleted && 
                                isInCurrentMonthOrBefore(date: transaction.startDate)
                            }.reduce(0) { $0 + $1.amount }
                            
                            Text(String(format: "%.2f €", visiblePendingIncome))
                                .font(.title3)
                                .bold()
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section(header: Text("Completados")) {
                ForEach(sortedTransactions(transactions.filter { $0.isCompleted })) { transaction in
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
                            TransactionRow(transaction: transaction, selectedTab: $selectedTab)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        TransactionRow(transaction: transaction, selectedTab: $selectedTab)
                    }
                }
                
                if transactions.filter({ $0.isCompleted }).isEmpty {
                    Text("No hay transacciones completadas")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            
            if let completedTotal = completedTotal {
                if type == .expense && title == "Gastos" {
                    Section {
                        Button(action: {
                            withAnimation {
                                selectedTab = 3 // Navegar a la pestaña Más
                                // Primero desactivamos para asegurar que se active correctamente después
                                navigateToSuscripciones?.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToSuscripciones?.wrappedValue = true
                                }
                            }
                        }) {
                            HStack {
                                Text("Gastos pagados de otras cuentas")
                                Spacer()
                                HStack {
                                    // Calcular el total como la suma de los gastos de otras cuentas completados en el listado
                                    let suscripcionesPagadasTotal = viewModel.subscriptions.filter { $0.isCompleted && $0.type == .subscription }.reduce(0) { $0 + $1.amount }
                                    Text(String(format: "%.2f €", suscripcionesPagadasTotal))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.green)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            withAnimation {
                                selectedTab = 3 // Navegar a la pestaña Más
                                // Primero desactivamos para asegurar que se active correctamente después
                                navigateToGastosDiarios?.wrappedValue = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigateToGastosDiarios?.wrappedValue = true
                                }
                            }
                        }) {
                            HStack {
                                Text("Gastos diarios")
                                Spacer()
                                HStack {
                                    let total = viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                                    Text(String(format: "%.2f €", total))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.green)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Text("Total pagado")
                            Spacer()
                            let gastosPagados = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                            let suscripcionesPagadas = viewModel.subscriptions.filter { $0.isCompleted && $0.type == .subscription }.reduce(0) { $0 + $1.amount }
                            let gastosDiarios = viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                            let totalPagado = gastosPagados + suscripcionesPagadas + gastosDiarios
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f €", totalPagado))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.green)
                                
                                Text("Gastos: \(String(format: "%.2f", gastosPagados))€ + GPgO: \(String(format: "%.2f", suscripcionesPagadas))€ + GD: \(String(format: "%.2f", gastosDiarios))€")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    if type != .expense || title != "Gastos" {
                        if type == .income {
                            // Verificar si se deben mostrar las propinas según la preferencia del usuario
                            if UserDefaults.standard.bool(forKey: "showTips") {
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
                                    HStack {
                                        Text("Propinas")
                                        Spacer()
                                        HStack {
                                            if let tipsTransaction = viewModel.findTipsTransaction() {
                                                let total = viewModel.getCurrentMonthTipsTotal(tipTransaction: tipsTransaction)
                                                Text(String(format: "%.2f €", total))
                                                    .font(.title3)
                                                    .bold()
                                                    .foregroundColor(.orange)
                                            } else {
                                                Text("0.00 €")
                                                    .font(.title3)
                                                    .bold()
                                                    .foregroundColor(.orange)
                                            }
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text(type == .income ? "Total cobrado" : "Total pagado")
                            Spacer()
                            if type == .expense {
                                if title == "Gastos de otras cuentas" {
                                    // Calcular el total exclusivamente con las transacciones mostradas en la sección "Completados"
                                    let completedSum = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                                    Text(String(format: "%.2f €", completedSum))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.green)
                                } else {
                                    let completedSum = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                                    Text(String(format: "%.2f €", completedSum))
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.green)
                                }
                            } else if type == .income {
                                // Para ingresos, mostrar el total cobrado sin incluir propinas si están desactivadas
                                let showTips = UserDefaults.standard.bool(forKey: "showTips")
                                let completedSum = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                                
                                // Si showTips es true, usar el valor proporcionado por completedTotal
                                // Si showTips es false, usar solo el valor calculado de las transacciones visibles
                                let totalMostrado = showTips ? completedTotal ?? completedSum : completedSum
                                
                                Text(String(format: "%.2f €", totalMostrado))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.green)
                            } else {
                                // Para cualquier otro tipo, mostrar SOLO las transacciones completadas
                                let completedSum = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                                Text(String(format: "%.2f €", completedSum))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            if let total = total {
                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        if type == .expense && title == "Gastos de otras cuentas" {
                            // En gastos de otras cuentas, el total debe incluir solo las transacciones visibles actuales
                            let now = Date()
                            let visibleSubscriptions = transactions.filter { 
                                // Filtrar transacciones futuras
                                !($0.startDate != nil && $0.startDate! > now)
                            }
                            let subscriptionsTotal = visibleSubscriptions.reduce(0) { $0 + $1.amount }
                            
                            Text(String(format: "%.2f €", subscriptionsTotal))
                                .font(.title3)
                                .bold()
                                .foregroundColor(Color.blue.opacity(0.7))
                        } else if type == .expense && title == "Gastos" {
                            // Calcular el total como la suma exacta de:
                            // 1. Todos los items del listado Pendientes
                            let pendingItems = transactions.filter { 
                                !$0.isCompleted && isInCurrentMonthOrBefore(date: $0.startDate)
                            }.reduce(0) { $0 + $1.amount }
                            
                            // 2. Gastos pendientes de otras cuentas
                            let suscripcionesPendientes = viewModel.pendingSubscriptions
                            
                            // 3. Todos los items del listado Completados
                            let completedItems = transactions.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                            
                            // 4. Gastos pagados de otras cuentas
                            let suscripcionesPagadas = viewModel.subscriptions.filter { $0.isCompleted && $0.type == .subscription }.reduce(0) { $0 + $1.amount }
                            
                            // 5. Gastos diarios
                            let gastosDiarios = viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                            
                            // Sumar todos los componentes
                            let granTotal = pendingItems + suscripcionesPendientes + completedItems + suscripcionesPagadas + gastosDiarios
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f €", granTotal))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(Color.blue.opacity(0.7))
                                
                                // Mostrar desglose detallado
                                Text("Pend: \(String(format: "%.2f", pendingItems))€ + GPO: \(String(format: "%.2f", suscripcionesPendientes))€ + Compl: \(String(format: "%.2f", completedItems))€ + GPgO: \(String(format: "%.2f", suscripcionesPagadas))€ + GD: \(String(format: "%.2f", gastosDiarios))€")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if type == .income {
                            // Para ingresos, usar directamente los valores del ViewModel en lugar de recalcularlos
                            let totalPendiente = viewModel.pendingIncome
                            let totalCobrado = viewModel.completedIncome
                            
                            // Verificar si se deben mostrar las propinas
                            let showTips = UserDefaults.standard.bool(forKey: "showTips")
                            let totalPropinas = (showTips && viewModel.findTipsTransaction() != nil) ?
                                viewModel.getCurrentMonthTipsTotal(tipTransaction: viewModel.findTipsTransaction()!) : 0
                            
                            // Usar el valor total del ViewModel para mayor consistencia
                            let granTotal = viewModel.totalIncome
                            
                            VStack(alignment: .trailing, spacing: 2) {
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
                        } else {
                            // Para otros casos, usar el total proporcionado
                            Text(String(format: "%.2f €", total))
                                .font(.title3)
                                .bold()
                                .foregroundColor(Color.blue.opacity(0.7))
                        }
                    }
                }
                
                // Obtener transacciones futuras (eventos en próximos meses)
                let futureTransactions = getFutureTransactions()
                
                if !futureTransactions.isEmpty {
                    Section(header: Text("Eventos de meses futuros").foregroundColor(Color.gray)) {
                        ForEach(futureTransactions) { transaction in
                            Button(action: {
                                // Acción al tocar una transacción futura: mostrar editor
                                showingEditTransaction = transaction
                                
                                if transaction.type == .gp {
                                    // Para transacciones GP, usar el editor específico
                                    showingEditGPTransaction = true
                                } else {
                                    // Para otras transacciones, usar el editor estándar
                                    showingEditStandardTransaction = true
                                }
                            }) {
                                HStack(alignment: .center) {
                                    // Icono según tipo de transacción
                                    Image(systemName: getIconForFutureTransaction(transaction))
                                        .foregroundColor(Color.gray)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(transaction.concept)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        // Para transacciones con fecha de inicio en el futuro
                                        if let startDate = transaction.startDate, startDate > Date() {
                                            HStack(spacing: 6) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .font(.caption2)
                                                    .foregroundColor(Color.gray.opacity(0.8))
                                                
                                                Text("Inicia: \(formatNextAppearanceDate(startDate))")
                                                    .font(.caption)
                                                    .foregroundColor(Color.gray.opacity(0.8))
                                                
                                                if transaction.periodicity != .monthly {
                                                    Text("•")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    
                                                    Text(transaction.periodicity.rawValue)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        // Para transacciones periódicas no mensuales con próxima aparición
                                        else if transaction.periodicity != .monthly {
                                            Text(transaction.periodicity.rawValue)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.2f €", transaction.amount))
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(Color.gray)
                                        
                                    // Icono para indicar que es editable
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Color.gray.opacity(0.6))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Sección para verificar la consistencia de totales
            if type == .expense && title == "Gastos" {
                Section {
                    Button(action: {
                        viewModel.verifyTotalsConsistency()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.secondary)
                            Text("Verificar totales")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
            }
            
            // Botón de diagnóstico específico para ingresos
            if type == .income && title == "Ingresos" {
                Section {
                    Button(action: {
                        viewModel.debugIncomeTotals()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.secondary)
                            Text("Diagnosticar ingresos")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
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
        // Sheet para editar transacciones GP futuras
        .sheet(isPresented: $showingEditGPTransaction) {
            if let transaction = showingEditTransaction {
                EditGPTransactionView(transaction: transaction)
            }
        }
        // Sheet para editar transacciones estándar futuras
        .sheet(isPresented: $showingEditStandardTransaction) {
            if let transaction = showingEditTransaction {
                EditTransactionView(transaction: transaction)
            }
        }
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
}
