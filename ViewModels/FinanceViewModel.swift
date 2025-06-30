import Foundation
import SwiftUI
import WidgetKit

// Extensión para agregar método de comprobación de existencia de clave
extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

class FinanceViewModel: ObservableObject {
    @Published var incomes: [Transaction] = [] {
        didSet {
            StorageManager.shared.saveIncomes(incomes)
            updateDerivedProperties()
        }
    }
    
    @Published var expenses: [Transaction] = [] {
        didSet {
            StorageManager.shared.saveExpenses(expenses)
            updateDerivedProperties()
        }
    }
    
    @Published var subscriptions: [Transaction] = [] {
        didSet {
            StorageManager.shared.saveSubscriptions(subscriptions)
            updateDerivedProperties()
        }
    }
    
    @Published var gpTransactions: [Transaction] = [] {
        didSet {
            StorageManager.shared.saveGPTransactions(gpTransactions)
            updateDerivedProperties()
    }
    }
    
    @Published var tips: [Transaction] = [] {
        didSet {
            StorageManager.shared.saveTips(tips)
            updateDerivedProperties()
        }
    }
    
    @Published var showNextMonth: Bool = false {
        didSet {
            updateNextMonthDate()
        }
    }
    
    @Published var nextMonthDate: Date = {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }()
    
    // Variables para controlar la visualización de modales
    @Published var showingAddSubscriptionTransaction: Bool = false
    @Published var showingAddGPTransaction: Bool = false
    
    @Published private(set) var pendingIncome: Double = 0
    @Published private(set) var completedIncome: Double = 0
    @Published private(set) var pendingExpenses: Double = 0
    @Published private(set) var completedExpenses: Double = 0
    @Published private(set) var pendingSubscriptions: Double = 0
    @Published private(set) var completedSubscriptions: Double = 0
    @Published private(set) var pendingGP: Double = 0
    @Published private(set) var completedGP: Double = 0
    @Published private(set) var totalGP: Double = 0
    @Published private(set) var totalSubscriptions: Double = 0
    @Published private(set) var totalIncome: Double = 0
    @Published private(set) var totalExpenses: Double = 0
    
    // Variable para controlar si se muestran las propinas
    @Published var showTips: Bool = UserDefaults.standard.bool(forKey: "showTips")
    
    // Variable para los métodos de pago personalizados
    @Published var customPaymentMethods: [String] = []
    
    // Lista de categorías personalizadas
    @Published var customCategories: [String] = []
    
    // Propiedades para acceder a las transacciones
    var incomeTransactions: [Transaction] {
        get { incomes }
        set { incomes = newValue }
    }
    
    var expenseTransactions: [Transaction] {
        get { expenses }
        set { expenses = newValue }
    }
    
    init() {
        print("FinanceViewModel: Inicializando")
        // Cargar datos iniciales
        loadData()
        
        // Inicializar la preferencia de mostrar propinas
        if !UserDefaults.standard.contains(key: "showTips") {
            // Valor por defecto: true (mostrar propinas)
            UserDefaults.standard.set(true, forKey: "showTips")
            showTips = true
        } else {
            showTips = UserDefaults.standard.bool(forKey: "showTips")
        }
        
        // Cargar los métodos de pago personalizados
        loadCustomPaymentMethods()
        
        // Cargar categorías personalizadas
        loadCustomCategories()
        
        // Actualizar propiedades derivadas después de un breve retraso
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateDerivedProperties()
            
            // Actualizar específicamente los datos del widget al inicio
            self.updateWidgetData()
            
            print("FinanceViewModel: Inicialización completada")
        }
    }
    
    private func updateDerivedProperties() {
        print("FinanceViewModel: Actualizando propiedades derivadas")
        
        let now = Date()
        
        // Calcular totales de ingresos (excluyendo el ítem representativo de propinas y transacciones futuras)
        let allIncomes = incomes
        let newPendingIncome = allIncomes
            .filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
            .reduce(0) { $0 + $1.amount }
        let newCompletedIncome = allIncomes
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.amount }
        
        // Ya no añadimos el total de propinas a los ingresos
        let finalCompletedIncome = newCompletedIncome
        
        // Calcular totales de gastos (excluyendo Gastos Diarios y transacciones futuras)
        let nonGPExpenses = expenses.filter { $0.concept != "Gastos Diarios" }
        let newPendingExpenses = nonGPExpenses
            .filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
            .reduce(0) { $0 + $1.amount }
        let newCompletedExpenses = nonGPExpenses
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.amount }
        
        // Calcular totales de suscripciones (excluyendo transacciones futuras)
        let newPendingSubscriptions = subscriptions
            .filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
            .reduce(0) { $0 + $1.amount }
        let newCompletedSubscriptions = subscriptions
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.amount }
        
        // Calcular totales de GP (excluyendo transacciones futuras)
        let newPendingGP = gpTransactions
            .filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
            .reduce(0) { $0 + $1.amount }
        let newCompletedGP = gpTransactions
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.amount }
        
        // Calcular el total de propinas del mes actual - solo si showTips es true
        let totalPropinas = (showTips && findTipsTransaction() != nil) ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Actualizar todos los totales independientemente de si han cambiado
        pendingIncome = newPendingIncome
        completedIncome = finalCompletedIncome
        
        // Actualizar el total de ingresos con el cálculo correcto
        let newTotalIncome = pendingIncome + completedIncome + totalPropinas
        if totalIncome != newTotalIncome {
            print("FinanceViewModel: Actualizando totalIncome de \(totalIncome)€ a \(newTotalIncome)€")
            totalIncome = newTotalIncome
        }
        
        pendingExpenses = newPendingExpenses
        completedExpenses = newCompletedExpenses
        totalExpenses = pendingExpenses + completedExpenses + newPendingSubscriptions + newCompletedSubscriptions + newPendingGP + newCompletedGP
        
        pendingSubscriptions = newPendingSubscriptions
        completedSubscriptions = newCompletedSubscriptions
        totalSubscriptions = pendingSubscriptions + completedSubscriptions
        
        pendingGP = newPendingGP
        completedGP = newCompletedGP
        totalGP = pendingGP + completedGP
        
        // Verificar la consistencia de los totales
        verifyTotalsConsistency()
        
        // Actualizar los datos del widget
        updateWidgetData()
        
        // Forzar la notificación de cambio para asegurar que todas las vistas se actualicen
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("FinanceViewModel: Propiedades derivadas actualizadas")
    }
    
    func loadData() {
        print("FinanceViewModel: Iniciando carga de datos")
        
        // Cargar GP primero
        gpTransactions = StorageManager.shared.loadGPTransactions()
        print("StorageManager: Transacciones GP cargadas correctamente: \(gpTransactions.count)")
        
        // Cargar tips
        tips = StorageManager.shared.loadTips()
        print("StorageManager: Propinas cargadas correctamente: \(tips.count)")
        
        // Cargar ingresos (excluyendo propinas)
        incomes = StorageManager.shared.loadIncomes().filter { $0.type != .tips && $0.concept != "Propinas" }
        print("StorageManager: Ingresos cargados correctamente: \(incomes.count)")
        
        // Guardar los ingresos filtrados para asegurar que se eliminan las propinas permanentemente
        StorageManager.shared.saveIncomes(incomes)
        
        // Cargar suscripciones
        subscriptions = StorageManager.shared.loadSubscriptions()
        print("StorageManager: Suscripciones cargadas correctamente: \(subscriptions.count)")
        
        // Cargar gastos (excluyendo Gastos Diarios)
        expenses = StorageManager.shared.loadExpenses().filter { $0.concept != "Gastos Diarios" }
        print("StorageManager: Gastos cargados correctamente: \(expenses.count)")
        
        // Guardar los gastos filtrados para asegurar que se eliminan los Gastos Diarios permanentemente
        StorageManager.shared.saveExpenses(expenses)
        
        updateDerivedProperties()
        
        // Verificar la consistencia de los totales después de cargar
        verifyTotalsConsistency()
    }
    
    func getCurrentMonthTipsTotal(tipTransaction: Transaction) -> Double {
        guard let weeklyAmounts = tipTransaction.weeklyAmounts else {
            print("TipsView: No hay transacción para calcular total mensual")
            return 0
        }
        
        // Sumar todas las cantidades del listado
        let total = weeklyAmounts.values.reduce(0) { sum, weekTip in
            return sum + weekTip
        }
        
        print("TipsView: Total mensual calculado: \(total)€")
        return total
    }
    
    // Método específico para actualizar totales de ingresos
    func updateIncomeData() {
        print("FinanceViewModel: Actualizando específicamente datos de ingresos")
        
        let now = Date()
        
        // Recalcular totales de ingresos
        let allIncomes = incomes
        let newPendingIncome = allIncomes
            .filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
            .reduce(0) { $0 + $1.amount }
        let newCompletedIncome = allIncomes
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.amount }
        
        // Calcular el total de propinas del mes actual
        let totalPropinas = findTipsTransaction() != nil ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Actualizar los totales de ingresos
        pendingIncome = newPendingIncome
        completedIncome = newCompletedIncome
        totalIncome = pendingIncome + completedIncome + totalPropinas
        
        // Verificar la consistencia de los totales
        verifyTotalsConsistency()
        
        // Actualizar los datos del widget
        updateWidgetData()
        
        // Forzar la notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("FinanceViewModel: Datos de ingresos actualizados")
    }
    
    func addTransaction(_ transaction: Transaction) {
        print("FinanceViewModel: Añadiendo transacción - Tipo: \(transaction.type), Concepto: \(transaction.concept)")
        
        // Si es una transacción con fecha futura y periodicidad no mensual, asegurarse de calcular correctamente la próxima aparición
        var transactionToAdd = transaction
        if let startDate = transaction.startDate, startDate > Date(), transaction.periodicity != .monthly {
            // Forzar el recálculo de la próxima fecha de aparición
            print("FinanceViewModel: Recalculando próxima aparición para transacción futura con periodicidad \(transaction.periodicity.rawValue)")
            transactionToAdd.nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                startDate: startDate,
                lastResetDate: nil,
                periodicity: transaction.periodicity
            )
            if let nextDate = transactionToAdd.nextAppearanceDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                print("FinanceViewModel: Próxima aparición calculada: \(formatter.string(from: nextDate))")
            }
        }
        
        // Ejecutar método de diagnóstico para verificar los cálculos
        self.diagnoseTransaction(transactionToAdd, action: "Añadir")
        
        let isIncome = transactionToAdd.type == .income
        
        switch transactionToAdd.type {
        case .income:
            incomes.append(transactionToAdd)
            StorageManager.shared.saveIncomes(incomes)
        case .expense:
            if transactionToAdd.concept != "Gastos Diarios" {
                expenses.append(transactionToAdd)
                StorageManager.shared.saveExpenses(expenses)
            }
        case .subscription:
            subscriptions.append(transactionToAdd)
            StorageManager.shared.saveSubscriptions(subscriptions)
        case .tips:
            tips.append(transactionToAdd)
            StorageManager.shared.saveTips(tips)
        case .gp:
            gpTransactions.append(transactionToAdd)
            StorageManager.shared.saveGPTransactions(gpTransactions)
        }
        
        // Forzar actualización de la interfaz
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Si es un ingreso, actualizar específicamente los totales de ingresos
        if isIncome {
            updateIncomeData()
        } else {
            updateDerivedProperties()
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        print("FinanceViewModel: Eliminando transacción - Tipo: \(transaction.type), Concepto: \(transaction.concept)")
        
        let isIncome = transaction.type == .income
        
        switch transaction.type {
        case .income:
            incomes.removeAll { $0.id == transaction.id }
            StorageManager.shared.saveIncomes(incomes)
        case .expense:
            expenses.removeAll { $0.id == transaction.id }
            StorageManager.shared.saveExpenses(expenses)
        case .subscription:
            subscriptions.removeAll { $0.id == transaction.id }
            StorageManager.shared.saveSubscriptions(subscriptions)
        case .tips:
            tips.removeAll { $0.id == transaction.id }
            StorageManager.shared.saveTips(tips)
        case .gp:
            gpTransactions.removeAll { $0.id == transaction.id }
            StorageManager.shared.saveGPTransactions(gpTransactions)
        }
        
        // Forzar actualización de la interfaz
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Si es un ingreso, actualizar específicamente los totales de ingresos
        if isIncome {
            updateIncomeData()
        } else {
            updateDerivedProperties()
        }
    }
    
    var benefits: Double {
        (pendingIncome + completedIncome) - (pendingExpenses + completedExpenses)
    }
    
    func toggleTransactionCompletion(_ transaction: Transaction) -> (success: Bool, message: String?) {
        let currentDate = Date()
        
        // Si es una transacción de tipo propinas que está intentando ser desmarcada
        if transaction.type == .tips && transaction.isCompleted {
            // Verificar si hay propinas registradas para el mes actual
            let calendar = Calendar.current
            let now = Date()
            
            // Obtener el primer y último día del mes actual
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = 1
            guard let startOfMonth = calendar.date(from: components),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                return (true, nil) // En caso de error, permitir la acción por defecto
            }
            
            if let weeklyAmounts = transaction.weeklyAmounts {
                // Filtrar para ver si hay montos para el mes actual
                let hasCurrentMonthRecords = weeklyAmounts.contains { (date, _) in
                    return date >= startOfMonth && date <= endOfMonth
                }
                
                if hasCurrentMonthRecords {
                    // No permitir desmarcar y devolver mensaje
                    return (false, "Este item no se puede desmarcar porque las propinas ya han sido cobradas")
                }
            }
        }
        
        var wasModified = false
        
        // Proceder con la lógica normal para otros tipos de transacciones o si no hay propinas registradas
        switch transaction.type {
        case .income:
            if let index = incomes.firstIndex(where: { $0.id == transaction.id }) {
                if !incomes[index].isCompleted {
                    incomes[index].lastResetDate = currentDate
                }
                incomes[index].isCompleted.toggle()
                wasModified = true
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if incomes[index].isCompleted {
                    incomes[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: incomes[index].startDate,
                        lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                        periodicity: incomes[index].periodicity
                    )
                }
            }
        case .expense:
            if let index = expenses.firstIndex(where: { $0.id == transaction.id }) {
                if !expenses[index].isCompleted {
                    expenses[index].lastResetDate = currentDate
                }
                expenses[index].isCompleted.toggle()
                wasModified = true
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if expenses[index].isCompleted {
                    expenses[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: expenses[index].startDate,
                        lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                        periodicity: expenses[index].periodicity
                    )
                }
            }
        case .subscription:
            if let index = subscriptions.firstIndex(where: { $0.id == transaction.id }) {
                if !subscriptions[index].isCompleted {
                    subscriptions[index].lastResetDate = currentDate
                }
                subscriptions[index].isCompleted.toggle()
                wasModified = true
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if subscriptions[index].isCompleted {
                    subscriptions[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: subscriptions[index].startDate,
                        lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                        periodicity: subscriptions[index].periodicity
                    )
                }
            }
        case .tips:
            if let index = tips.firstIndex(where: { $0.id == transaction.id }) {
                if !tips[index].isCompleted {
                    tips[index].lastResetDate = currentDate
                }
                tips[index].isCompleted.toggle()
                wasModified = true
            }
        case .gp:
            if let index = gpTransactions.firstIndex(where: { $0.id == transaction.id }) {
                if !gpTransactions[index].isCompleted {
                    gpTransactions[index].lastResetDate = currentDate
                }
                gpTransactions[index].isCompleted.toggle()
                wasModified = true
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if gpTransactions[index].isCompleted {
                    gpTransactions[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: gpTransactions[index].startDate,
                        lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                        periodicity: gpTransactions[index].periodicity
                    )
                }
            }
        }
        
        // Si hubo modificación, actualizar todos los totales y enviar notificación
        if wasModified {
            // Guardar cambios en el almacenamiento según el tipo
            switch transaction.type {
            case .income:
                StorageManager.shared.saveIncomes(incomes)
            case .expense:
                StorageManager.shared.saveExpenses(expenses)
            case .subscription:
                StorageManager.shared.saveSubscriptions(subscriptions)
            case .tips:
                StorageManager.shared.saveTips(tips)
            case .gp:
                StorageManager.shared.saveGPTransactions(gpTransactions)
            }
            
            // Forzar recálculo de todos los totales
            updateDerivedProperties()
            
            // Forzar actualización de la interfaz
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        return (true, nil)
    }
    
    func resetCompletedTransactions() {
        // Verificar si estamos en día 25 o posterior
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: Date())
        
        if currentDay >= 25 {
            showNextMonth = true
        }
        
        let currentDate = Date()
        
        // Función para determinar si debe resetearse una transacción basada en su periodicidad
        func shouldResetTransaction(_ transaction: Transaction) -> Bool {
            // Si la periodicidad es mensual, siempre resetear
            if transaction.periodicity == .monthly {
                return true
            }
            
            // Si la periodicidad es semanal, verificar si ha pasado una semana
            if transaction.periodicity == .weekly {
                let calendar = Calendar.current
                // Comprobar si ha pasado al menos una semana desde el último reset
                if let lastResetDate = transaction.lastResetDate,
                   let nextResetDate = calendar.date(byAdding: .day, value: 7, to: lastResetDate) {
                    return currentDate >= nextResetDate
                }
                return false
            }
            
            // Si nunca se ha reseteado antes, resetear ahora
            guard let lastResetDate = transaction.lastResetDate else {
                return true
            }
            
            // Calcular los meses que deben pasar según la periodicidad
            let calendar = Calendar.current
            var monthsToAdd = 1
            
            switch transaction.periodicity {
            case .weekly:
                monthsToAdd = 0 // Para semanal, manejamos diferente - se resetea cada semana
            case .monthly:
                monthsToAdd = 1
            case .bimonthly:
                monthsToAdd = 2
            case .quarterly:
                monthsToAdd = 3
            case .semiannual:
                monthsToAdd = 6
            case .annual:
                monthsToAdd = 12
            case .biannual:
                monthsToAdd = 24
            }
            
            // Calcular la próxima fecha de reseteo
            if let nextResetDate = calendar.date(byAdding: .month, value: monthsToAdd, to: lastResetDate) {
                // Si la fecha actual es posterior a la próxima fecha de reseteo, entonces resetear
                return currentDate >= nextResetDate
            }
            
            return false
        }
        
        // Resetear ingresos
        for i in 0..<incomes.count {
            if incomes[i].isCompleted {
                if shouldResetTransaction(incomes[i]) {
                    incomes[i].isCompleted = false
                    incomes[i].lastResetDate = currentDate
                    // Actualizar la fecha de próxima aparición
                    incomes[i].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: incomes[i].startDate,
                        lastResetDate: currentDate,
                        periodicity: incomes[i].periodicity
                    )
                }
            }
        }
        
        // Resetear gastos (excepto "Suscripciones")
        for i in 0..<expenses.count {
            if expenses[i].isCompleted && expenses[i].concept != "Gastos de otras cuentas" {
                if shouldResetTransaction(expenses[i]) {
                    expenses[i].isCompleted = false
                    expenses[i].lastResetDate = currentDate
                    // Actualizar la fecha de próxima aparición
                    expenses[i].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: expenses[i].startDate,
                        lastResetDate: currentDate,
                        periodicity: expenses[i].periodicity
                    )
                }
            }
        }
        
        // Resetear suscripciones
        for i in 0..<subscriptions.count {
            if subscriptions[i].isCompleted {
                if shouldResetTransaction(subscriptions[i]) {
                    subscriptions[i].isCompleted = false
                    subscriptions[i].lastResetDate = currentDate
                    // Actualizar la fecha de próxima aparición
                    subscriptions[i].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                        startDate: subscriptions[i].startDate,
                        lastResetDate: currentDate,
                        periodicity: subscriptions[i].periodicity
                    )
                }
            }
        }
        
        // Borrar completamente todos los gastos diarios (gpTransactions)
        if !gpTransactions.isEmpty {
            print("FinanceViewModel: Eliminando todos los gastos diarios al restablecer ciclo - Total: \(gpTransactions.count)")
            gpTransactions.removeAll()
            StorageManager.shared.saveGPTransactions(gpTransactions)
            updateDerivedProperties()
        }
        
        // Resetear propinas
        for i in 0..<tips.count {
            if tips[i].isCompleted {
                if shouldResetTransaction(tips[i]) {
                    tips[i].isCompleted = false
                    tips[i].lastResetDate = currentDate
                }
            }
        }
        
        // Notificar que se ha realizado un reseteo importante
        print("FinanceViewModel: Ciclo de transacciones restablecido")
        self.objectWillChange.send()
        
        // Actualizar los datos del widget
        WidgetDataProvider.shared.updateWidgetData()
    }
    
    // MARK: - Funciones para gestionar propinas
    
    func findTipsTransaction() -> Transaction? {
        // Buscar si ya existe una transacción de tipo propinas
        return tips.first { $0.type == .tips }
    }
    
    func addWeeklyTips(amount: Double, date: Date, note: String) -> (success: Bool, message: String?) {
        print("FinanceViewModel: Añadiendo propina: \(amount)€ para fecha \(date)")
        
        // Validar que la fecha no sea futura
        let calendar = Calendar.current
        let today = Date()
        let comparison = calendar.compare(date, to: today, toGranularity: .day)
        
        if comparison == .orderedDescending {
            return (false, "No te adelantes a los acontecimientos. Esta fecha es posterior a la actual")
        }
        
        // Normalizar la fecha al inicio de la semana
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStartDate = calendar.date(from: weekComponents) else {
            return (false, "Error al calcular la fecha de la semana")
        }
        
        // Verificar si ya existe una transacción de propinas
        if let tipsTransaction = findTipsTransaction() {
            // Si ya existe una transacción de propinas, añadir un monto semanal
            print("FinanceViewModel: Añadiendo a transacción de propinas existente")
            
            var weeklyAmounts = tipsTransaction.weeklyAmounts ?? [:]
            
            // Si ya hay un registro para esta semana, sumarlo
            if let existingAmount = weeklyAmounts[weekStartDate] {
                let newAmount = existingAmount + amount
                weeklyAmounts[weekStartDate] = newAmount
                print("FinanceViewModel: Actualizando monto existente de \(existingAmount)€ a \(newAmount)€")
            } else {
                // Nuevo registro para esta semana
                weeklyAmounts[weekStartDate] = amount
                print("FinanceViewModel: Añadiendo nuevo monto semanal: \(amount)€")
            }
            
            // Actualizar la transacción
            var updatedTransaction = tipsTransaction
            updatedTransaction.weeklyAmounts = weeklyAmounts
            updatedTransaction.amount = weeklyAmounts.values.reduce(0, +)
            
            // Actualizar en el array
            if let index = tips.firstIndex(where: { $0.id == tipsTransaction.id }) {
                tips[index] = updatedTransaction
                StorageManager.shared.saveTips(tips)
                
                // Forzar la actualización de los totales después de modificar propinas
                updateDerivedProperties()
                
                // Actualizar específicamente el total de ingresos
                updateTotalIncome()
                
                return (true, nil)
            } else {
                return (false, "Error al actualizar las propinas")
            }
        } else {
            // Crear una nueva transacción de propinas
            print("FinanceViewModel: Creando nueva transacción de propinas")
            let weeklyAmounts = [weekStartDate: amount]
            
            // Crear una nueva transacción
            let tipsTransaction = Transaction(
                amount: amount,
                concept: "Propinas",
                isCompleted: true,
                type: .tips,
                periodicity: .monthly,
                paymentType: .manual,
                paymentMethod: .cash,
                weekDay: .friday,
                automaticPaymentOption: nil,
                startDate: weekStartDate,
                weeklyAmounts: weeklyAmounts
            )
            
            // Añadir la nueva transacción
            tips.append(tipsTransaction)
            StorageManager.shared.saveTips(tips)
            
            // Forzar la actualización de los totales después de añadir propinas
            updateDerivedProperties()
            
            // Actualizar específicamente el total de ingresos
            updateTotalIncome()
            
            return (true, nil)
        }
    }
    
    // Función para actualizar el total de ingresos con el monto actualizado de propinas
    func updateTotalIncome() {
        print("FinanceViewModel: Actualizando total de ingresos...")
        
        // Verificar valores actuales
        print("- Pendientes actuales: \(pendingIncome)€")
        print("- Cobrados actuales: \(completedIncome)€")
        
        // Calcular el total de propinas actual, respetando la preferencia del usuario
        let totalPropinas = (showTips && findTipsTransaction() != nil) ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        print("- Propinas calculadas: \(totalPropinas)€")
        print("- Mostrar propinas: \(showTips ? "SÍ" : "NO")")
        
        // Actualizar el total de ingresos considerando propinas
        let nuevoTotal = pendingIncome + completedIncome + totalPropinas
        totalIncome = nuevoTotal
        
        print("FinanceViewModel: Total de ingresos actualizado a \(nuevoTotal)€")
        
        // Forzar la notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Actualizar los datos del widget para que reflejen el nuevo total
        updateWidgetData()
    }
    
    // Nueva función auxiliar para mantener sincronizado el ítem de propinas en incomes
    private func updateTipsIncomeItem() {
        print("FinanceViewModel: Iniciando actualización del ítem de propinas en ingresos")
        
        // Eliminar el ítem anterior de propinas en incomes
        incomes = incomes.filter { $0.type != .tips }
        print("FinanceViewModel: Ítem anterior de propinas eliminado de ingresos")
        
        // Calcular el total actual de propinas usando el mismo método que getCurrentMonthTipsTotal
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var totalTips = 0.0
        for tip in tips {
            if let weeklyAmounts = tip.weeklyAmounts {
                for (date, amount) in weeklyAmounts {
                    let tipMonth = calendar.component(.month, from: date)
                    let tipYear = calendar.component(.year, from: date)
                    if tipMonth == currentMonth && tipYear == currentYear {
                        totalTips += amount
                    }
                }
            }
        }
        
        print("FinanceViewModel: Total de propinas calculado: \(totalTips)€")
        
        // Crear y añadir el nuevo ítem de propinas
        let tipsIncome = Transaction(
            amount: totalTips,
            concept: "Propinas",
            isCompleted: true,
            type: .tips,
            periodicity: .monthly,
            paymentType: .manual,
            paymentMethod: .cash
        )
        incomes.append(tipsIncome)
        print("FinanceViewModel: Nuevo ítem de propinas añadido a ingresos")
        
        // Guardar los cambios
        StorageManager.shared.saveIncomes(incomes)
        print("FinanceViewModel: Cambios guardados en el almacenamiento")
        
        // Actualizar totalIncome para reflejar los cambios
        totalIncome = pendingIncome + completedIncome
        
        // Forzar la notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("FinanceViewModel: Notificación de cambio enviada")
        }
    }
    
    func getWeeklySummaries(tipTransaction: Transaction) -> [(date: Date, amount: Double)] {
        guard let weeklyAmounts = tipTransaction.weeklyAmounts else {
            return []
        }
        
        // Convertir a array y ordenar por fecha
        let summaries = weeklyAmounts.map { (date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
        
        print("FinanceViewModel: Obteniendo \(summaries.count) resúmenes semanales")
        return summaries
    }
    
    func getMonthlyTipsTotals(tipTransaction: Transaction) -> [(month: String, total: Double)] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.dateFormat = "MMMM yyyy"
        
        // Agrupar propinas por mes
        var monthlyTotals: [String: Double] = [:]
        
        guard let weeklyAmounts = tipTransaction.weeklyAmounts else {
            return []
        }
        
        for (date, amount) in weeklyAmounts {
            let monthYear = dateFormatter.string(from: date)
            if let existing = monthlyTotals[monthYear] {
                monthlyTotals[monthYear] = existing + amount
            } else {
                monthlyTotals[monthYear] = amount
            }
        }
        
        // Convertir a array de tuplas y ordenar por fecha (más reciente primero)
        var sortedMonths = [(month: String, total: Double)]()
        
        for (month, total) in monthlyTotals {
            sortedMonths.append((month: month, total: total))
        }
        
        // Ordenar por fecha (más reciente primero)
        sortedMonths.sort { (month1, month2) in
            // Necesitamos convertir los strings de mes a fechas para ordenar
            guard let date1 = dateFormatter.date(from: month1.month),
                  let date2 = dateFormatter.date(from: month2.month) else {
                return false
            }
            return date1 > date2
        }
        
        return sortedMonths
    }
    
    func getLastWeekdayOfWeek(in date: Date) -> Date {
        let calendar = Calendar.current
        
        // Conseguir el inicio de la semana (lunes)
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let startOfWeek = calendar.date(from: weekComponents) else { return date }
        
        // Buscar el viernes (día 5 de la semana)
        var fridayComponents = DateComponents()
        fridayComponents.weekday = 6 // 6 = viernes en calendario que comienza en domingo
        
        guard let friday = calendar.nextDate(after: startOfWeek, matching: fridayComponents, matchingPolicy: .nextTime) else {
            return date
        }
        
        // Verificar si es día laborable
        let holidays = [Date]() // Aquí se pueden añadir días festivos conocidos
        
        if calendar.isDateInWeekend(friday) || holidays.contains(where: { calendar.isDate($0, inSameDayAs: friday) }) {
            // Si el viernes es fin de semana o festivo, buscar el jueves
            var thursdayComponents = DateComponents()
            thursdayComponents.weekday = 5 // 5 = jueves
            
            if let thursday = calendar.nextDate(after: startOfWeek, matching: thursdayComponents, matchingPolicy: .nextTime) {
                return thursday
            }
        }
        
        return friday
    }
    
    func deleteWeeklyTips(date: Date) -> Bool {
        print("FinanceViewModel: Eliminando propina para fecha \(date)")
        
        // Normalizar la fecha al inicio de la semana
        let calendar = Calendar.current
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStartDate = calendar.date(from: weekComponents) else {
            return false
        }
        
        if let tipsTransaction = findTipsTransaction(),
           var weeklyAmounts = tipsTransaction.weeklyAmounts {
            
            // Verificar si existe un registro para esta semana
            guard weeklyAmounts[weekStartDate] != nil else {
                return false
            }
            
            // Eliminar el registro de esta semana
            weeklyAmounts.removeValue(forKey: weekStartDate)
            
            // Crear una transacción actualizada
            var updatedTransaction = tipsTransaction
            updatedTransaction.weeklyAmounts = weeklyAmounts.isEmpty ? nil : weeklyAmounts
            updatedTransaction.amount = weeklyAmounts.values.reduce(0, +)
            
            // Actualizar o eliminar la transacción
            if weeklyAmounts.isEmpty {
                tips.removeAll { $0.id == tipsTransaction.id }
            } else {
                if let index = tips.firstIndex(where: { $0.id == tipsTransaction.id }) {
                    tips[index] = updatedTransaction
                }
            }
            
            // Guardar los cambios
            StorageManager.shared.saveTips(tips)
            
            // Forzar la actualización de los totales después de eliminar propinas
            updateDerivedProperties()
            
            // Actualizar específicamente el total de ingresos
            updateTotalIncome()
            
            return true
        }
        return false
    }
    
    func clearPreviousTips() -> (success: Bool, message: String?) {
        // Verificar si hay transacción de propinas
        guard let tipsTransaction = findTipsTransaction(),
              let weeklyAmounts = tipsTransaction.weeklyAmounts else {
            return (false, "No hay propinas registradas que limpiar")
        }
        
        // Obtener fecha actual
        let calendar = Calendar.current
        let now = Date()
        
        // Obtener el primer día del mes actual
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 1
        guard let startOfMonth = calendar.date(from: components) else {
            return (false, "Error al calcular el inicio del mes")
        }
        
        // Filtrar solo las propinas del mes actual
        let currentMonthAmounts = weeklyAmounts.filter { date, _ in
            return date >= startOfMonth
        }
        
        // Contar registros eliminados
        let removedCount = weeklyAmounts.count - currentMonthAmounts.count
        
        if removedCount == 0 {
            return (false, "No hay registros de meses anteriores para limpiar")
        }
        
        // Crear transacción actualizada
        var updatedTransaction = tipsTransaction
        updatedTransaction.weeklyAmounts = currentMonthAmounts.isEmpty ? nil : currentMonthAmounts
        updatedTransaction.amount = currentMonthAmounts.values.reduce(0, +)
        
        // Actualizar o eliminar la transacción
        if currentMonthAmounts.isEmpty {
            tips.removeAll { $0.id == tipsTransaction.id }
        } else {
            if let index = tips.firstIndex(where: { $0.id == tipsTransaction.id }) {
                tips[index] = updatedTransaction
            }
        }
        
        // Guardar los cambios
        StorageManager.shared.saveTips(tips)
        
        // Forzar la actualización de los totales después de limpiar propinas
        updateDerivedProperties()
        
        // Actualizar específicamente el total de ingresos
        updateTotalIncome()
        
        return (true, "Se han eliminado \(removedCount) registros de meses anteriores")
    }
    
    private func updateNextMonthDate() {
        let calendar = Calendar.current
        if showNextMonth {
            nextMonthDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        } else {
            nextMonthDate = Date()
        }
    }
    
    private func diagnoseTransaction(_ transaction: Transaction, action: String) {
        print("\n==== DIAGNÓSTICO DE TRANSACCIÓN (\(action)) ====")
        print("ID: \(transaction.id)")
        print("Concepto: \(transaction.concept)")
        print("Tipo: \(transaction.type.rawValue)")
        print("Periodicidad: \(transaction.periodicity.rawValue)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        dateFormatter.locale = Locale(identifier: "es_ES")
        
        if let startDate = transaction.startDate {
            print("Fecha de inicio: \(dateFormatter.string(from: startDate))")
        } else {
            print("Fecha de inicio: nil")
        }
        
        if let endDate = transaction.endDate {
            print("Fecha de fin: \(dateFormatter.string(from: endDate))")
        } else {
            print("Fecha de fin: nil")
        }
        
        if let lastResetDate = transaction.lastResetDate {
            print("Última fecha de reset: \(dateFormatter.string(from: lastResetDate))")
        } else {
            print("Última fecha de reset: nil")
        }
        
        if let nextAppearanceDate = transaction.nextAppearanceDate {
            print("Próxima aparición: \(dateFormatter.string(from: nextAppearanceDate))")
            
            // Calcular diferencia con fecha de inicio
            if let startDate = transaction.startDate {
                let calendar = Calendar.current
                let diffComponents = calendar.dateComponents([.day, .month, .year], from: startDate, to: nextAppearanceDate)
                print("Diferencia desde inicio: \(diffComponents.year ?? 0) años, \(diffComponents.month ?? 0) meses, \(diffComponents.day ?? 0) días")
                
                // Verificar si la diferencia coincide con la periodicidad
                var esCorrectaPeriodicidad = false
                switch transaction.periodicity {
                case .weekly:
                    esCorrectaPeriodicidad = diffComponents.day == 7
                case .monthly:
                    esCorrectaPeriodicidad = diffComponents.month == 1 && diffComponents.year == 0
                case .bimonthly:
                    esCorrectaPeriodicidad = diffComponents.month == 2 && diffComponents.year == 0
                case .quarterly:
                    esCorrectaPeriodicidad = diffComponents.month == 3 && diffComponents.year == 0
                case .semiannual:
                    esCorrectaPeriodicidad = diffComponents.month == 6 && diffComponents.year == 0
                case .annual:
                    esCorrectaPeriodicidad = diffComponents.year == 1
                case .biannual:
                    esCorrectaPeriodicidad = diffComponents.year == 2
                }
                
                print("¿Cumple periodicidad correcta? \(esCorrectaPeriodicidad ? "SÍ" : "NO")")
            }
        } else {
            print("Próxima aparición: nil")
        }
        
        print("Completada: \(transaction.isCompleted)")
        print("==== FIN DIAGNÓSTICO ====\n")
    }
    
    // Método de diagnóstico para verificar la consistencia de totales
    func verifyTotalsConsistency() {
        let now = Date()
        
        // 1. Verificar ingresos
        let incomesVisible = incomes.filter { 
            !$0.isCompleted && 
            !($0.startDate != nil && $0.startDate! > now) 
        }
        let incomesHidden = incomes.filter { 
            !$0.isCompleted && 
            ($0.startDate != nil && $0.startDate! > now) 
        }
        let visibleIncomesTotal = incomesVisible.reduce(0) { $0 + $1.amount }
        let hiddenIncomesTotal = incomesHidden.reduce(0) { $0 + $1.amount }
        
        print("=== DIAGNÓSTICO DE TOTALES ===")
        print("INGRESOS:")
        print("- Pendiente visible: \(visibleIncomesTotal)€ (\(incomesVisible.count) items)")
        print("- Pendiente oculto (futuro): \(hiddenIncomesTotal)€ (\(incomesHidden.count) items)")
        print("- Total calculado: \(pendingIncome)€")
        
        // 2. Verificar gastos
        let expensesVisible = expenses.filter { 
            !$0.isCompleted && 
            !($0.startDate != nil && $0.startDate! > now) 
        }
        let expensesHidden = expenses.filter { 
            !$0.isCompleted && 
            ($0.startDate != nil && $0.startDate! > now) 
        }
        let visibleExpensesTotal = expensesVisible.reduce(0) { $0 + $1.amount }
        let hiddenExpensesTotal = expensesHidden.reduce(0) { $0 + $1.amount }
        
        print("GASTOS:")
        print("- Pendiente visible: \(visibleExpensesTotal)€ (\(expensesVisible.count) items)")
        print("- Pendiente oculto (futuro): \(hiddenExpensesTotal)€ (\(expensesHidden.count) items)")
        print("- Total calculado: \(pendingExpenses)€")
        
        // 3. Verificar suscripciones
        let subscriptionsVisible = subscriptions.filter { 
            !$0.isCompleted && 
            !($0.startDate != nil && $0.startDate! > now) 
        }
        let subscriptionsHidden = subscriptions.filter { 
            !$0.isCompleted && 
            ($0.startDate != nil && $0.startDate! > now) 
        }
        let visibleSubscriptionsTotal = subscriptionsVisible.reduce(0) { $0 + $1.amount }
        let hiddenSubscriptionsTotal = subscriptionsHidden.reduce(0) { $0 + $1.amount }
        
        print("SUSCRIPCIONES:")
        print("- Pendiente visible: \(visibleSubscriptionsTotal)€ (\(subscriptionsVisible.count) items)")
        print("- Pendiente oculto (futuro): \(hiddenSubscriptionsTotal)€ (\(subscriptionsHidden.count) items)")
        print("- Total calculado: \(pendingSubscriptions)€")
        print("=== FIN DIAGNÓSTICO ===")
    }
    
    // Método para actualizar los datos del widget
    private func updateWidgetData() {
        print("FinanceViewModel: Actualizando datos del widget")
        
        // Verificar si el App Group está funcionando
        let appGroupID = "group.com.rogalan.TusFinanzas"
        if UserDefaults(suiteName: appGroupID) != nil {
            print("App puede acceder al App Group: SÍ")
        } else {
            print("App puede acceder al App Group: NO (ESTO ES UN PROBLEMA)")
        }
        
        // Calcular el beneficio total según la previsión (totalIncome - totalExpenses)
        let totalBeneficio = totalIncome - totalExpenses
        
        print("FinanceViewModel: Calculando beneficio para el widget:")
        print("- Total Ingresos: \(totalIncome)")
        print("- Total Gastos: \(totalExpenses)")
        print("- Beneficio según previsión: \(totalBeneficio)")
        
        // Obtener total de propinas, solo si showTips es true
        let tipsTotal = (showTips && findTipsTransaction() != nil) ? 
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Crear objeto WidgetData con los totales actuales
        let widgetData = WidgetData(
            totalIngresos: totalIncome,
            totalGastos: totalExpenses, // Ahora usamos totalExpenses que incluye todo
            totalSuscripciones: totalSubscriptions,
            totalGP: totalGP,
            totalPropinas: tipsTotal,
            beneficio: totalBeneficio, // Usamos el beneficio calculado según previsión
            fechaActualizacion: Date()
        )
        
        print("FinanceViewModel: Datos para widget preparados:")
        print("- Ingresos: \(widgetData.totalIngresos)")
        print("- Gastos: \(widgetData.totalGastos)")
        print("- Suscripciones: \(widgetData.totalSuscripciones)")
        print("- GP: \(widgetData.totalGP)")
        print("- Propinas: \(widgetData.totalPropinas)")
        print("- Beneficio: \(widgetData.beneficio)")
        
        // Guardar los datos y recargar el widget
        WidgetDataProvider.shared.saveWidgetData(widgetData)
        
        // Intentar guardar directamente en App Group como respaldo
        if let groupDefaults = UserDefaults(suiteName: appGroupID),
           let encodedData = try? JSONEncoder().encode(widgetData) {
            groupDefaults.set(encodedData, forKey: "widgetData")
            print("FinanceViewModel: Datos guardados directamente en App Group: SÍ")
        }
        
        // Forzar recarga del widget
        WidgetCenter.shared.reloadAllTimelines()
        print("FinanceViewModel: Widget recargado")
    }
    
    // Método público para actualizar todos los totales
    func refreshTotals() {
        // Actualizar todas las propiedades derivadas
        self.updateDerivedProperties()
        
        // Asegurarse específicamente de que el total de ingresos está correcto
        let totalPropinas = (showTips && findTipsTransaction() != nil) ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Actualizar explícitamente el total de ingresos
        totalIncome = pendingIncome + completedIncome + totalPropinas
        
        // Forzar una notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Actualizar los datos del widget con los totales recién calculados
        updateWidgetData()
        
        print("FinanceViewModel: Totales actualizados - Ingresos total: \(totalIncome)€")
    }
    
    // Método de diagnóstico para los ingresos
    func debugIncomeTotals() {
        print("\n==== DIAGNÓSTICO DE TOTALES DE INGRESOS ====")
        print("Pendientes: \(pendingIncome)€")
        print("Cobrados: \(completedIncome)€")
        
        // Calcular propinas de forma independiente
        let totalPropinas = (showTips && findTipsTransaction() != nil) ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        print("Propinas: \(totalPropinas)€")
        print("Mostrar propinas: \(showTips ? "SÍ" : "NO")")
        print("Total calculado (pendingIncome + completedIncome + propinas): \(pendingIncome + completedIncome + totalPropinas)€")
        print("Total publicado (totalIncome): \(totalIncome)€")
        
        // Verificar si hay discrepancia
        if totalIncome != (pendingIncome + completedIncome + totalPropinas) {
            print("⚠️ DISCREPANCIA DETECTADA: El totalIncome no coincide con la suma de sus componentes")
        } else {
            print("✓ Total verificado: No hay discrepancias")
        }
        
        print("==== FIN DIAGNÓSTICO ====\n")
        
        // Forzar actualización de los totales para corregir cualquier inconsistencia
        updateTotalIncome()
    }
    
    // Método para filtrar ingresos según la configuración de mostrar propinas
    func getFilteredIncomesForDisplay() -> [Transaction] {
        // Si showTips es true, mostrar todos los ingresos
        if showTips {
            return incomes
        } else {
            // Filtrar excluyendo las transacciones con concepto "Propinas" o tipo ".tips"
            return incomes.filter { $0.concept != "Propinas" && $0.type != .tips }
        }
    }
    
    // Método para actualizar el cálculo de propinas basado en la preferencia del usuario
    func updateShowTipsPreference(_ showTips: Bool) {
        print("FinanceViewModel: Actualizando preferencia de mostrar propinas: \(showTips)")
        self.showTips = showTips
        
        // Actualizar los cálculos y las vistas
        updateDerivedProperties()
        
        // Actualizar los datos del widget
        updateWidgetData()
        
        // Forzar notificación de cambio para que las vistas se actualicen
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Método para cargar los métodos de pago personalizados
    private func loadCustomPaymentMethods() {
        customPaymentMethods = StorageManager.shared.loadPaymentMethods()
    }
    
    // Método público para recargar los métodos de pago personalizados
    func reloadCustomPaymentMethods() {
        loadCustomPaymentMethods()
        // Notificar cambios para que todas las vistas se actualicen
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Método para obtener todos los métodos de pago (predefinidos + personalizados)
    func getAllPaymentMethods() -> [String] {
        // Comenzar con los métodos predefinidos, excepto el caso "custom"
        var allMethods = PaymentMethod.allCases
            .filter { $0 != .custom } // Filtrar el caso custom
            .map { $0.rawValue }
        
        // Añadir los personalizados, evitando duplicados
        for method in customPaymentMethods {
            if !allMethods.contains(method) {
                allMethods.append(method)
            }
        }
        
        return allMethods
    }
    
    // Método para cargar las categorías personalizadas
    private func loadCustomCategories() {
        customCategories = StorageManager.shared.loadCategories()
    }
    
    // Método público para recargar las categorías personalizadas
    func reloadCustomCategories() {
        loadCustomCategories()
        // Notificar cambios para que todas las vistas se actualicen
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Método para obtener todas las categorías (predefinidas + personalizadas)
    func getAllCategories() -> [String] {
        // Comenzar con las categorías predefinidas, excepto "Otros" que irá al final
        var allCategories = GPCategory.allCases
            .filter { $0.rawValue != "Otros" }
            .map { $0.rawValue }
        
        // Añadir las personalizadas, evitando duplicados y "Otros"
        for category in customCategories {
            if !allCategories.contains(category) && category != "Otros" {
                allCategories.append(category)
            }
        }
        
        // Añadir "Otros" siempre al final
        allCategories.append("Otros")
        
        return allCategories
    }
    
    // MARK: - Limpieza de archivos backup
    
    func cleanBackupFiles() -> (success: Bool, message: String?) {
        print("FinanceViewModel: Iniciando limpieza de archivos backup")
        
        let result = StorageManager.shared.cleanBackupFiles()
        
        print("FinanceViewModel: Resultado de limpieza - Éxito: \(result.success), Archivos eliminados: \(result.filesDeleted)")
        
        return (result.success, result.message)
    }
} 
