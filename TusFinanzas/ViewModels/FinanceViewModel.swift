import Foundation
import SwiftUI
import WidgetKit
import UserNotifications

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
            
            // Actualizar notificaciones si hay cambios en los gastos
            if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                updateExpenseNotifications()
            }
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
        
        // Inicializar las horas de notificación si no están configuradas
        if !UserDefaults.standard.contains(key: "notificationHour") {
            UserDefaults.standard.set(9, forKey: "notificationHour") // Hora por defecto: 9:00
            print("FinanceViewModel: Configurada hora por defecto para notificaciones: 9:00")
        }
        if !UserDefaults.standard.contains(key: "notificationMinute") {
            UserDefaults.standard.set(0, forKey: "notificationMinute")
            print("FinanceViewModel: Configurados minutos por defecto para notificaciones: 0")
        }
        if !UserDefaults.standard.contains(key: "dayBeforeNotificationHour") {
            UserDefaults.standard.set(10, forKey: "dayBeforeNotificationHour") // Hora por defecto: 10:00
            print("FinanceViewModel: Configurada hora por defecto para notificaciones del día anterior: 10:00")
        }
        if !UserDefaults.standard.contains(key: "dayBeforeNotificationMinute") {
            UserDefaults.standard.set(0, forKey: "dayBeforeNotificationMinute")
            print("FinanceViewModel: Configurados minutos por defecto para notificaciones del día anterior: 0")
        }
        
        // Inicializar el estado de las notificaciones si no está configurado
        if !UserDefaults.standard.contains(key: "expenseNotificationsEnabled") {
            UserDefaults.standard.set(true, forKey: "expenseNotificationsEnabled")
            print("FinanceViewModel: Notificaciones de gastos habilitadas por defecto")
        }
        
        // Cargar los métodos de pago personalizados
        loadCustomPaymentMethods()
        
        // Cargar categorías personalizadas
        loadCustomCategories()
        
        // Observar cambios en las horas de notificación
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationTimeChange),
            name: NSNotification.Name("RescheduleAllNotifications"),
            object: nil
        )
        
        // Actualizar propiedades derivadas después de un breve retraso
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateDerivedProperties()
            
            // Actualizar específicamente los datos del widget al inicio
            self.updateWidgetData()
            
            // Verificar y programar notificaciones si están habilitadas
            if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                print("FinanceViewModel: Notificaciones habilitadas, verificando permisos...")
                NotificationManager.shared.checkPermission { authorized in
                    if authorized {
                        print("FinanceViewModel: Permisos concedidos, programando notificaciones...")
                        self.scheduleExpenseNotifications()
                    } else {
                        print("FinanceViewModel: No hay permisos para notificaciones, solicitando...")
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                print("FinanceViewModel: Permisos concedidos, programando notificaciones...")
                                self.scheduleExpenseNotifications()
                            } else {
                                print("FinanceViewModel: Permisos denegados, desactivando notificaciones...")
                                UserDefaults.standard.set(false, forKey: "expenseNotificationsEnabled")
                            }
                        }
                    }
                }
            }
            
            print("FinanceViewModel: Inicialización completada")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleNotificationTimeChange() {
        print("FinanceViewModel: Recibida notificación de cambio de hora de notificaciones")
        // Reprogramar todas las notificaciones con las nuevas horas
        scheduleExpenseNotifications()
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
        
        // Actualizar los totales de ingresos
        pendingIncome = newPendingIncome
        completedIncome = newCompletedIncome
        
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
        
        // Actualizar todos los totales
        pendingExpenses = newPendingExpenses
        completedExpenses = newCompletedExpenses
        pendingSubscriptions = newPendingSubscriptions
        completedSubscriptions = newCompletedSubscriptions
        pendingGP = newPendingGP
        completedGP = newCompletedGP
        
        // Calcular y actualizar el total de propinas
        let totalPropinas = (showTips && findTipsTransaction() != nil) ?
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Actualizar el total de ingresos
        totalIncome = pendingIncome + completedIncome + totalPropinas
        
        // Actualizar el total de gastos (pendientes + pagados)
        // Debe incluir todos los componentes: gastos normales (pendientes y pagados) + suscripciones (pendientes y pagadas) + gastos personales
        totalExpenses = pendingExpenses + completedExpenses + pendingSubscriptions + completedSubscriptions + gpTransactions.reduce(0) { $0 + $1.amount }
        
        // Actualizar los datos del widget
        updateWidgetData()
        
        print("FinanceViewModel: Propiedades derivadas actualizadas:")
        print("- Ingresos pendientes: \(pendingIncome)€")
        print("- Ingresos completados: \(completedIncome)€")
        print("- Propinas: \(totalPropinas)€")
        print("- Total de ingresos: \(totalIncome)€")
        print("- Total de gastos: \(totalExpenses)€ (pendientes: \(pendingExpenses + pendingSubscriptions)€, pagados: \(completedExpenses + completedSubscriptions)€, GP: \(gpTransactions.reduce(0) { $0 + $1.amount })€)")
        
        // Forzar la notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
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
        if let startDate = transaction.startDate {
            // Calcular los meses de aparición según la periodicidad
            transactionToAdd.appearanceMonths = Transaction.calculateAppearanceMonths(
                startDate: startDate,
                endDate: transaction.endDate,
                periodicity: transaction.periodicity
            )
            
            // Calcular la fecha de próxima aparición basada en los meses calculados
            if startDate > Date() {
                // Si la fecha de inicio es futura, la próxima aparición es la fecha de inicio
                transactionToAdd.nextAppearanceDate = startDate
            } else {
                // Si la fecha de inicio es pasada, buscar el siguiente mes de aparición
                transactionToAdd.nextAppearanceDate = determineNextAppearanceDate(transaction: transactionToAdd)
            }
            
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
                
                // Si las notificaciones están habilitadas, programar para el nuevo gasto
                if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                    // Programar notificación para el nuevo gasto
                    if let nextDate = transactionToAdd.nextAppearanceDate, !transactionToAdd.isCompleted {
                        let transactionId = transactionToAdd.id.uuidString
                        
                        // Solo programar si la fecha es futura
                        let calendar = Calendar.current
                        let now = Date()
                        if calendar.compare(nextDate, to: now, toGranularity: .day) == .orderedDescending {
                            NotificationManager.shared.scheduleExpenseNotificationDayBefore(
                                transactionId: transactionId,
                                concept: transactionToAdd.concept,
                                amount: transactionToAdd.amount,
                                date: nextDate,
                                periodicity: transactionToAdd.periodicity.rawValue,
                                paymentMethod: transactionToAdd.paymentMethod.rawValue
                            )
                            
                            NotificationManager.shared.scheduleExpenseNotificationSameDay(
                                transactionId: transactionId,
                                concept: transactionToAdd.concept,
                                amount: transactionToAdd.amount,
                                date: nextDate,
                                periodicity: transactionToAdd.periodicity.rawValue,
                                paymentMethod: transactionToAdd.paymentMethod.rawValue
                            )
                            
                            print("FinanceViewModel: Notificaciones programadas para nuevo gasto")
                        }
                    }
                }
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
    
    // Método para determinar la próxima fecha de aparición basándose en los meses calculados
    private func determineNextAppearanceDate(transaction: Transaction) -> Date? {
        // Crear el formateador de fechas al inicio del método para usarlo en todo el ámbito
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        guard let startDate = transaction.startDate else {
            let result = Transaction.calculateNextAppearanceDate(
                startDate: transaction.startDate,
                lastResetDate: transaction.lastResetDate,
                periodicity: transaction.periodicity
            )
            
            if let fecha = result {
                print("Método tradicional (sin startDate) para \(transaction.concept): \(formatter.string(from: fecha))")
            }
            
            return result
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Obtener el día del mes de la fecha de inicio para mantenerlo en la fecha calculada
        let dayOfMonth = calendar.component(.day, from: startDate)
        
        // Si la transacción tiene periodicidad diferente a mensual
        if transaction.periodicity != .monthly {
            // Calcular incremento según periodicidad
            var incrementoMeses = 1
            
            switch transaction.periodicity {
            case .weekly:
                incrementoMeses = 0 // Caso especial: será semanal, no mensual
            case .monthly:
                incrementoMeses = 1
            case .bimonthly:
                incrementoMeses = 2
            case .quarterly:
                incrementoMeses = 3
            case .semiannual:
                incrementoMeses = 6
            case .annual:
                incrementoMeses = 12
            case .biannual:
                incrementoMeses = 24
            }
            
            // Si es una transacción completada, necesitamos calcular la próxima fecha
            if transaction.isCompleted {
                var baseDate: Date
                
                // Si hay fecha de último reset, usar esa como base para calcular
                if let lastResetDate = transaction.lastResetDate {
                    baseDate = lastResetDate
                    print("Usando fecha de último reset (\(formatter.string(from: lastResetDate))) como base para \(transaction.concept)")
                } else {
                    // Si no hay fecha de último reset, usar hoy
                    baseDate = today
                    print("No hay fecha de último reset para \(transaction.concept), usando fecha actual")
                }
                
                // Para periodicidad semanal
                if transaction.periodicity == .weekly {
                    // Añadir 7 días desde la fecha base
                    if let nextDate = calendar.date(byAdding: .day, value: 7, to: baseDate) {
                        print("Próxima fecha (semanal) para \(transaction.concept): \(formatter.string(from: nextDate))")
                        return nextDate
                    }
                } else {
                    // Para otras periodicidades, añadir los meses correspondientes
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
                    
                    // Mantener el mismo día del mes que la fecha de inicio
                    dateComponents.day = dayOfMonth
                    
                    // Calcular el mes siguiente según la periodicidad
                    if let month = dateComponents.month {
                        dateComponents.month = month + incrementoMeses
                    }
                    
                    // Asegurarse de que el día es válido para el nuevo mes
                    if let newDate = calendar.date(from: dateComponents) {
                        print("Próxima fecha para \(transaction.concept) (\(transaction.periodicity.rawValue)): \(formatter.string(from: newDate))")
                        return newDate
                    }
                }
            } 
            // Si no está completada pero tiene una fecha de inicio futura
            else if startDate > today {
                print("Transacción \(transaction.concept) con fecha futura: \(formatter.string(from: startDate))")
                return startDate
            }
            // Si la transacción no está completada pero la fecha de inicio ya pasó
            else {
                // Si no está completada, la próxima fecha es la fecha de inicio convertida al mes actual o siguiente
                var components = calendar.dateComponents([.year, .month], from: today)
                components.day = dayOfMonth
                
                // Si el día actual es posterior al día del mes de la transacción,
                // avanzar al mes siguiente para pendientes
                let currentDay = calendar.component(.day, from: today)
                if currentDay > dayOfMonth {
                    if let month = components.month {
                        components.month = month + 1
                    }
                }
                
                // Asegurar que el día es válido para el mes calculado
                if let calculatedDate = calendar.date(from: components) {
                    print("Transacción pendiente \(transaction.concept): fecha calculada \(formatter.string(from: calculatedDate))")
                    return calculatedDate
                }
            }
        }
        
        // Si llegamos aquí, o si es periodicidad mensual, o si falló el cálculo específico,
        // usar el método tradicional de cálculo
        let resultado = Transaction.calculateNextAppearanceDate(
            startDate: transaction.startDate,
            lastResetDate: transaction.lastResetDate,
            periodicity: transaction.periodicity
        )
        
        if let fecha = resultado {
            print("Método tradicional para \(transaction.concept): \(formatter.string(from: fecha))")
        } else {
            print("No se pudo calcular fecha para \(transaction.concept) con método tradicional")
        }
        
        return resultado
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
            
            // Cancelar notificaciones para el gasto eliminado
            if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                NotificationManager.shared.cancelExpenseNotifications(transactionId: transaction.id.uuidString)
                print("FinanceViewModel: Notificaciones canceladas para gasto eliminado")
            }
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
        print("FinanceViewModel: Iniciando toggle para transacción de tipo \(transaction.type.rawValue)")
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
                let currentState = incomes[index].isCompleted
                
                // Cambiar el estado a lo contrario
                incomes[index].isCompleted.toggle()
                
                // Si estaba completado y ahora se desmarca, mostrar mensaje de diagnóstico
                if currentState && !incomes[index].isCompleted {
                    print("FinanceViewModel: Ingreso desmarcado - ID: \(transaction.id), Concepto: \(transaction.concept)")
                }
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if incomes[index].isCompleted {
                    // Guardar la fecha actual como fecha de último reset
                    incomes[index].lastResetDate = currentDate
                    
                    // Recalcular la fecha de próxima aparición utilizando los meses de aparición
                    if incomes[index].appearanceMonths != nil {
                        incomes[index].nextAppearanceDate = determineNextAppearanceDate(transaction: incomes[index])
                    } else {
                        // Si no tiene meses de aparición calculados, utilizar el método tradicional
                        incomes[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                            startDate: incomes[index].startDate,
                            lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                            periodicity: incomes[index].periodicity
                        )
                    }
                }
                
                wasModified = true
            }
        case .expense:
            if let index = expenses.firstIndex(where: { $0.id == transaction.id }) {
                let currentState = expenses[index].isCompleted
                
                // Cambiar el estado a lo contrario
                expenses[index].isCompleted.toggle()
                wasModified = true
                
                // Si estaba completado y ahora se desmarca, recalcular la fecha de próxima aparición
                if currentState && !expenses[index].isCompleted {
                    print("FinanceViewModel: Gasto desmarcado - ID: \(transaction.id), Concepto: \(transaction.concept)")
                    
                    // Recalcular la fecha de próxima aparición para elemento pendiente
                    // Es importante no usar la fecha de último reset aquí
                    if let startDate = expenses[index].startDate {
                        print("Desmarcando gasto: \(expenses[index].concept) (Periodicidad: \(expenses[index].periodicity.rawValue))")
                        
                        // Recalcular directamente la próxima fecha de aparición para pendiente
                        let nuevaFecha = determineNextAppearanceDate(transaction: expenses[index])
                        expenses[index].nextAppearanceDate = nuevaFecha
                        
                        if let nextDate = expenses[index].nextAppearanceDate {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "dd/MM/yyyy"
                            print("Próxima fecha de cargo recalculada para pendiente: \(formatter.string(from: nextDate))")
                        }
                    }
                }
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if expenses[index].isCompleted {
                    // Guardar la fecha actual como fecha de último reset
                    expenses[index].lastResetDate = currentDate
                    
                    // Diagnóstico para seguimiento
                    print("Completando gasto: \(expenses[index].concept)")
                    print("Periodicidad: \(expenses[index].periodicity.rawValue)")
                    print("Fecha de último reset: \(currentDate)")
                    
                    // Recalcular directamente la próxima fecha de aparición
                    // El método determineNextAppearanceDate ya tiene en cuenta la periodicidad
                    let nuevaFecha = determineNextAppearanceDate(transaction: expenses[index])
                    expenses[index].nextAppearanceDate = nuevaFecha
                    
                    if let nextDate = expenses[index].nextAppearanceDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd/MM/yyyy"
                        print("Próxima fecha de cargo calculada: \(formatter.string(from: nextDate))")
                        
                        // Si las notificaciones están habilitadas, actualizar para la nueva fecha
                        if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                            // Primero cancelar las notificaciones existentes
                            NotificationManager.shared.cancelExpenseNotifications(transactionId: expenses[index].id.uuidString)
                            
                            // Luego programar para la nueva fecha si es futura
                            let calendar = Calendar.current
                            if calendar.compare(nextDate, to: currentDate, toGranularity: .day) == .orderedDescending {
                                NotificationManager.shared.scheduleExpenseNotificationDayBefore(
                                    transactionId: expenses[index].id.uuidString,
                                    concept: expenses[index].concept,
                                    amount: expenses[index].amount,
                                    date: nextDate,
                                    periodicity: expenses[index].periodicity.rawValue,
                                    paymentMethod: expenses[index].paymentMethod.rawValue
                                )
                                
                                NotificationManager.shared.scheduleExpenseNotificationSameDay(
                                    transactionId: expenses[index].id.uuidString,
                                    concept: expenses[index].concept,
                                    amount: expenses[index].amount,
                                    date: nextDate,
                                    periodicity: expenses[index].periodicity.rawValue,
                                    paymentMethod: expenses[index].paymentMethod.rawValue
                                )
                                
                                print("FinanceViewModel: Notificaciones actualizadas para gasto completado")
                            }
                        }
                    } else {
                        print("Error: No se pudo calcular la próxima fecha")
                        
                        // Cancelar notificaciones ya que no hay fecha próxima
                        if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                            NotificationManager.shared.cancelExpenseNotifications(transactionId: expenses[index].id.uuidString)
                        }
                    }
                    
                    // Diagnóstico adicional de la transacción actualizada
                    self.diagnoseTransaction(expenses[index], action: "Completada")
                } else {
                    // Si se marca como pendiente, programar notificaciones si hay fecha próxima
                    if let nextDate = expenses[index].nextAppearanceDate, UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
                        let calendar = Calendar.current
                        if calendar.compare(nextDate, to: currentDate, toGranularity: .day) == .orderedDescending {
                            NotificationManager.shared.scheduleExpenseNotificationDayBefore(
                                transactionId: expenses[index].id.uuidString,
                                concept: expenses[index].concept,
                                amount: expenses[index].amount,
                                date: nextDate,
                                periodicity: expenses[index].periodicity.rawValue,
                                paymentMethod: expenses[index].paymentMethod.rawValue
                            )
                            
                            NotificationManager.shared.scheduleExpenseNotificationSameDay(
                                transactionId: expenses[index].id.uuidString,
                                concept: expenses[index].concept,
                                amount: expenses[index].amount,
                                date: nextDate,
                                periodicity: expenses[index].periodicity.rawValue,
                                paymentMethod: expenses[index].paymentMethod.rawValue
                            )
                            
                            print("FinanceViewModel: Notificaciones programadas para gasto marcado como pendiente")
                        }
                    }
                }
            }
        case .subscription:
            if let index = subscriptions.firstIndex(where: { $0.id == transaction.id }) {
                let currentState = subscriptions[index].isCompleted
                
                // Cambiar el estado a lo contrario
                subscriptions[index].isCompleted.toggle()
                
                // Si estaba completado y ahora se desmarca, recalcular la fecha de próxima aparición
                if currentState && !subscriptions[index].isCompleted {
                    print("FinanceViewModel: Suscripción desmarcada - ID: \(transaction.id), Concepto: \(transaction.concept)")
                    
                    // Recalcular la fecha de próxima aparición para elemento pendiente
                    // Es importante no usar la fecha de último reset aquí
                    if let startDate = subscriptions[index].startDate {
                        print("Desmarcando suscripción: \(subscriptions[index].concept) (Periodicidad: \(subscriptions[index].periodicity.rawValue))")
                        
                        // Recalcular directamente la próxima fecha de aparición para pendiente
                        let nuevaFecha = determineNextAppearanceDate(transaction: subscriptions[index])
                        subscriptions[index].nextAppearanceDate = nuevaFecha
                        
                        if let nextDate = subscriptions[index].nextAppearanceDate {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "dd/MM/yyyy"
                            print("Próxima fecha de cargo recalculada para pendiente: \(formatter.string(from: nextDate))")
                        }
                    }
                }
                
                // Si no estaba completado, guardar la fecha actual como último reset
                if !currentState && subscriptions[index].isCompleted {
                    subscriptions[index].lastResetDate = currentDate
                }
                
                // Actualizar nextAppearanceDate si la transacción ha sido completada
                if subscriptions[index].isCompleted {
                    // Guardar la fecha actual como fecha de último reset
                    subscriptions[index].lastResetDate = currentDate
                    
                    // Diagnóstico para seguimiento
                    print("Completando suscripción: \(subscriptions[index].concept)")
                    print("Periodicidad: \(subscriptions[index].periodicity.rawValue)")
                    print("Fecha de último reset: \(currentDate)")
                    
                    // Recalcular directamente la próxima fecha de aparición
                    // El método determineNextAppearanceDate ya tiene en cuenta la periodicidad
                    let nuevaFecha = determineNextAppearanceDate(transaction: subscriptions[index])
                    subscriptions[index].nextAppearanceDate = nuevaFecha
                    
                    if let nextDate = subscriptions[index].nextAppearanceDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd/MM/yyyy"
                        print("Próxima fecha de cargo calculada: \(formatter.string(from: nextDate))")
                    } else {
                        print("Error: No se pudo calcular la próxima fecha")
                    }
                    
                    // Diagnóstico adicional de la transacción actualizada
                    self.diagnoseTransaction(subscriptions[index], action: "Completada")
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
                    // Guardar la fecha actual como fecha de último reset
                    gpTransactions[index].lastResetDate = currentDate
                    
                    // Recalcular la fecha de próxima aparición utilizando los meses de aparición
                    if gpTransactions[index].appearanceMonths != nil {
                        gpTransactions[index].nextAppearanceDate = determineNextAppearanceDate(transaction: gpTransactions[index])
                    } else {
                        // Si no tiene meses de aparición calculados, utilizar el método tradicional
                        gpTransactions[index].nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                            startDate: gpTransactions[index].startDate,
                            lastResetDate: currentDate, // Usar la fecha actual como lastResetDate
                            periodicity: gpTransactions[index].periodicity
                        )
                    }
                }
            }
        }
        
        // Si hubo modificación, actualizar todos los totales y enviar notificación
        if wasModified {
            // Guardar cambios en el almacenamiento según el tipo
            switch transaction.type {
            case .income:
                print("FinanceViewModel: Guardando cambios en ingresos")
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
            
            // Para ingresos, actualizar específicamente totales de ingresos
            if transaction.type == .income {
                // No llamamos updateIncomeData aquí porque se llamará desde TransactionRow
                print("FinanceViewModel: Transacción de ingresos modificada, actualización pendiente")
            } else {
                // Forzar recálculo de todos los totales para otros tipos
                updateDerivedProperties()
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
            // Si ya existe una transacción de propinas, actualizar el monto semanal
            print("FinanceViewModel: Actualizando transacción de propinas existente")
            
            var weeklyAmounts = tipsTransaction.weeklyAmounts ?? [:]
            
            // Reemplazar el valor existente o añadir uno nuevo
            weeklyAmounts[weekStartDate] = amount
            print("FinanceViewModel: Actualizando monto para la semana a \(amount)€")
            
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
        print("FinanceViewModel: Iniciando eliminación de propina para fecha \(date)")
        
        // Normalizar la fecha al inicio de la semana
        let calendar = Calendar.current
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStartDate = calendar.date(from: weekComponents) else {
            print("FinanceViewModel: Error al normalizar la fecha")
            return false
        }
        
        print("FinanceViewModel: Fecha normalizada: \(weekStartDate)")
        
        if let tipsTransaction = findTipsTransaction() {
            print("FinanceViewModel: Transacción de propinas encontrada - ID: \(tipsTransaction.id)")
            
            guard var weeklyAmounts = tipsTransaction.weeklyAmounts else {
                print("FinanceViewModel: No hay registros semanales en la transacción")
                return false
            }
            
            // Verificar si existe un registro para esta semana
            guard let amountToDelete = weeklyAmounts[weekStartDate] else {
                print("FinanceViewModel: No hay registro para la semana del \(weekStartDate)")
                return false
            }
            
            print("FinanceViewModel: Eliminando registro de \(amountToDelete)€ para la semana del \(weekStartDate)")
            
            // Eliminar el registro de esta semana
            weeklyAmounts.removeValue(forKey: weekStartDate)
            print("FinanceViewModel: Registro eliminado. Quedan \(weeklyAmounts.count) registros")
            
            // Crear una transacción actualizada
            var updatedTransaction = tipsTransaction
            updatedTransaction.weeklyAmounts = weeklyAmounts.isEmpty ? nil : weeklyAmounts
            updatedTransaction.amount = weeklyAmounts.values.reduce(0, +)
            
            // Actualizar o eliminar la transacción
            if weeklyAmounts.isEmpty {
                print("FinanceViewModel: Eliminando transacción de propinas completa")
                tips.removeAll { $0.id == tipsTransaction.id }
            } else {
                if let index = tips.firstIndex(where: { $0.id == tipsTransaction.id }) {
                    print("FinanceViewModel: Actualizando transacción de propinas")
                    tips[index] = updatedTransaction
                }
            }
            
            // Guardar los cambios
            StorageManager.shared.saveTips(tips)
            print("FinanceViewModel: Cambios guardados en el almacenamiento")
            
            // Forzar la actualización de los totales después de eliminar propinas
            DispatchQueue.main.async {
                self.updateDerivedProperties()
                
                // Actualizar específicamente el total de ingresos
                self.updateTotalIncome()
                
                // Notificar cambios
                self.objectWillChange.send()
                print("FinanceViewModel: UI actualizada después de eliminar propina")
            }
            
            return true
        }
        print("FinanceViewModel: No se encontró transacción de propinas")
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
    
    // Método para diagnosticar una transacción
    func diagnoseTransaction(_ transaction: Transaction, action: String) {
        print("\n===== DIAGNÓSTICO DE TRANSACCIÓN (\(action)) =====")
        print("Tipo: \(transaction.type.rawValue)")
        print("Concepto: \(transaction.concept)")
        print("Periodicidad: \(transaction.periodicity.rawValue)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        if let startDate = transaction.startDate {
            print("Fecha inicio: \(dateFormatter.string(from: startDate))")
            print("Día de cargo establecido: \(Calendar.current.component(.day, from: startDate))")
        } else {
            print("Fecha inicio: No establecida")
        }
        
        if let endDate = transaction.endDate {
            print("Fecha fin: \(dateFormatter.string(from: endDate))")
        } else {
            print("Fecha fin: No establecida")
        }
        
        if let lastResetDate = transaction.lastResetDate {
            print("Última fecha reset: \(dateFormatter.string(from: lastResetDate))")
        } else {
            print("Última fecha reset: No establecida")
        }
        
        if let nextDate = transaction.nextAppearanceDate {
            print("Próxima fecha de cargo: \(dateFormatter.string(from: nextDate))")
        } else {
            print("Próxima fecha de cargo: No establecida")
        }
        
        // Diagnóstico de meses de aparición
        if let appearanceMonths = transaction.appearanceMonths {
            print("\nMeses de aparición calculados (\(appearanceMonths.count)):")
            
            // Crear un formateador solo para mes/año
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM yyyy"
            monthFormatter.locale = Locale(identifier: "es_ES")
            
            // Limitar a mostrar máximo 12 fechas para evitar salidas muy largas
            let maxDatesToShow = min(12, appearanceMonths.count)
            
            let dayOfMonth = transaction.startDate != nil ? 
                Calendar.current.component(.day, from: transaction.startDate!) : 1
            
            for i in 0..<maxDatesToShow {
                let month = appearanceMonths[i]
                let monthYear = monthFormatter.string(from: month)
                print("\(i+1). \(monthYear) (cargo el día \(dayOfMonth))")
            }
            
            if appearanceMonths.count > maxDatesToShow {
                print("... y \(appearanceMonths.count - maxDatesToShow) más")
            }
            
            // Verificar si el mes actual está en los meses de aparición
            let calendar = Calendar.current
            let today = Date()
            let currentMonth = calendar.component(.month, from: today)
            let currentYear = calendar.component(.year, from: today)
            
            let hasCurrentMonth = appearanceMonths.contains { month in
                let monthValue = calendar.component(.month, from: month)
                let yearValue = calendar.component(.year, from: month)
                return monthValue == currentMonth && yearValue == currentYear
            }
            
            print("\n¿El mes actual (\(monthFormatter.string(from: today))) está en los meses de aparición? \(hasCurrentMonth ? "SÍ" : "NO")")
        } else {
            print("\nMeses de aparición: No calculados")
        }
        
        print("=====\n")
    }
    
    // Método para probar el cálculo de los meses de aparición
    func testAppearanceMonthsCalculation() {
        Transaction.testAppearanceMonthsCalculation()
    }
    
    // Método para probar el cálculo de la próxima fecha de cargo
    func testNextChargeDate() {
        print("\n===== PRUEBA DE CÁLCULO DE PRÓXIMA FECHA DE CARGO =====")
        
        // Crear fechas de ejemplo para diferentes periodicidades
        let calendar = Calendar.current
        let today = Date()
        
        // Crear fecha de inicio (el día 15 del mes pasado)
        var startComponents = calendar.dateComponents([.year, .month], from: today)
        startComponents.month = startComponents.month! - 1
        startComponents.day = 15
        
        guard let startDate = calendar.date(from: startComponents) else {
            print("Error al crear fecha de inicio")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        print("Fecha actual: \(formatter.string(from: today))")
        print("Fecha de inicio: \(formatter.string(from: startDate))")
        print("Día de cargo establecido: 15")
        
        // Probar cada periodicidad
        for periodicity in Periodicity.allCases {
            print("\n=== Periodicidad: \(periodicity.rawValue) ===")
            
            // Crear una transacción de prueba
            let transaction = Transaction(
                amount: 100,
                concept: "Prueba \(periodicity.rawValue)",
                isCompleted: false,
                type: .expense,
                periodicity: periodicity,
                startDate: startDate
            )
            
            // Mostrar meses de aparición
            if let months = transaction.appearanceMonths {
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMMM yyyy"
                monthFormatter.locale = Locale(identifier: "es_ES")
                
                print("Meses de aparición calculados (\(months.count)):")
                for (i, month) in months.prefix(6).enumerated() {
                    print("\(i+1). \(monthFormatter.string(from: month))")
                }
                
                if months.count > 6 {
                    print("... y \(months.count - 6) más")
                }
            }
            
            // Calcular próxima fecha de cargo usando nuestro método
            if let nextDate = determineNextAppearanceDate(transaction: transaction) {
                print("Próxima fecha de cargo: \(formatter.string(from: nextDate))")
                
                // Verificar que el día sea correcto (debe ser 15 o el último día del mes si es febrero con 28/29 días)
                let dayOfMonth = calendar.component(.day, from: nextDate)
                let expectedDay = min(15, calendar.range(of: .day, in: .month, for: nextDate)?.count ?? 15)
                
                if dayOfMonth != expectedDay {
                    print("⚠️ ADVERTENCIA: El día del mes no coincide con el esperado")
                    print("Día calculado: \(dayOfMonth), Día esperado: \(expectedDay)")
                } else {
                    print("✓ Día del mes correcto: \(dayOfMonth)")
                }
                
                // Verificar que la fecha es futura
                if nextDate <= today {
                    print("⚠️ ADVERTENCIA: La próxima fecha no es futura")
                } else {
                    print("✓ La fecha es futura")
                }
            } else {
                print("❌ ERROR: No se pudo calcular la próxima fecha de cargo")
            }
        }
        
        print("===== FIN DE PRUEBA =====\n")
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
        
        // Calcular el total de gastos personales (GP) igual que en la pestaña "Más"
        let gastosDiarios = gpTransactions.reduce(0) { $0 + $1.amount }
        
        // Calcular el total de gastos como la suma de Total Pendiente + Total pagado
        // Es decir: pendingExpenses + completedExpenses + pendingSubscriptions + completedSubscriptions + gastosDiarios
        let totalGastosCombinados = pendingExpenses + completedExpenses + pendingSubscriptions + completedSubscriptions + gastosDiarios
        
        // Total de suscripciones (pendientes + pagadas) para mantener compatibilidad
        let totalSuscripciones = pendingSubscriptions + completedSubscriptions
        
        // Calcular el beneficio total según la previsión (totalIncome - totalGastosCombinados)
        let totalBeneficio = totalIncome - totalGastosCombinados
        
        print("FinanceViewModel: Calculando beneficio para el widget:")
        print("- Total Ingresos: \(totalIncome)")
        print("- Total Gastos Pendientes: \(pendingExpenses + pendingSubscriptions)")
        print("- Total Gastos Pagados: \(completedExpenses + completedSubscriptions + gastosDiarios)")
        print("- Total Gastos Combinados: \(totalGastosCombinados)")
        print("- Beneficio según previsión: \(totalBeneficio)")
        
        // Obtener total de propinas, solo si showTips es true
        let tipsTotal = (showTips && findTipsTransaction() != nil) ? 
            getCurrentMonthTipsTotal(tipTransaction: findTipsTransaction()!) : 0
        
        // Crear objeto WidgetData con los totales actuales
        let widgetData = WidgetData(
            totalIngresos: totalIncome,
            totalGastos: totalGastosCombinados, // Usar el total de todos los gastos combinados (pendientes + pagados)
            totalSuscripciones: totalSuscripciones, // Mantener por compatibilidad
            totalGP: gastosDiarios, // Usar el valor calculado de gastos diarios
            totalPropinas: tipsTotal,
            beneficio: totalBeneficio, // Usamos el beneficio calculado según previsión
            fechaActualizacion: Date()
        )
        
        print("FinanceViewModel: Datos para widget preparados:")
        print("- Ingresos: \(widgetData.totalIngresos)")
        print("- Gastos totales: \(widgetData.totalGastos)")
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
        
        // Actualizar explícitamente el total de gastos
        totalExpenses = pendingExpenses + completedExpenses + pendingSubscriptions + completedSubscriptions + gpTransactions.reduce(0) { $0 + $1.amount }
        
        // Forzar una notificación de cambio
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Actualizar los datos del widget con los totales recién calculados
        updateWidgetData()
        
        print("FinanceViewModel: Totales actualizados - Ingresos total: \(totalIncome)€, Gastos total: \(totalExpenses)€")
    }
    
    // Método para recalcular todas las fechas de próxima aparición en las transacciones existentes
    func recalculateAllAppearanceDates() {
        print("FinanceViewModel: Recalculando fechas de aparición para todas las transacciones...")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        // Recalcular fechas para gastos
        for i in 0..<expenses.count {
            if let startDate = expenses[i].startDate {
                let estadoActual = expenses[i].isCompleted ? "Completado" : "Pendiente"
                print("Recalculando para: \(expenses[i].concept) (Periodicidad: \(expenses[i].periodicity.rawValue), Estado: \(estadoActual))")
                
                // Mantener el estado actual de completado
                let estaCompletado = expenses[i].isCompleted
                
                // Calcular directamente la fecha de próxima aparición
                // El método determineNextAppearanceDate respetará el estado de completado
                expenses[i].nextAppearanceDate = determineNextAppearanceDate(transaction: expenses[i])
                
                // Asegurar que el estado de completado no ha cambiado
                expenses[i].isCompleted = estaCompletado
                
                // Mostrar resultado
                if let nextDate = expenses[i].nextAppearanceDate {
                    print("  • Nueva fecha de próxima aparición: \(formatter.string(from: nextDate)) (Estado: \(estadoActual))")
                } else {
                    print("  • No se pudo calcular una fecha válida")
                }
            }
        }
        
        // Recalcular fechas para suscripciones
        for i in 0..<subscriptions.count {
            if let startDate = subscriptions[i].startDate {
                let estadoActual = subscriptions[i].isCompleted ? "Completado" : "Pendiente"
                print("Recalculando para: \(subscriptions[i].concept) (Periodicidad: \(subscriptions[i].periodicity.rawValue), Estado: \(estadoActual))")
                
                // Mantener el estado actual de completado
                let estaCompletado = subscriptions[i].isCompleted
                
                // Calcular directamente la fecha de próxima aparición
                subscriptions[i].nextAppearanceDate = determineNextAppearanceDate(transaction: subscriptions[i])
                
                // Asegurar que el estado de completado no ha cambiado
                subscriptions[i].isCompleted = estaCompletado
                
                // Mostrar resultado
                if let nextDate = subscriptions[i].nextAppearanceDate {
                    print("  • Nueva fecha de próxima aparición: \(formatter.string(from: nextDate)) (Estado: \(estadoActual))")
                } else {
                    print("  • No se pudo calcular una fecha válida")
                }
            }
        }
        
        // Recalcular fechas para ingresos
        for i in 0..<incomes.count {
            if let startDate = incomes[i].startDate {
                let estadoActual = incomes[i].isCompleted ? "Completado" : "Pendiente"
                print("Recalculando para: \(incomes[i].concept) (Periodicidad: \(incomes[i].periodicity.rawValue), Estado: \(estadoActual))")
                
                // Mantener el estado actual de completado
                let estaCompletado = incomes[i].isCompleted
                
                // Calcular directamente la fecha de próxima aparición
                incomes[i].nextAppearanceDate = determineNextAppearanceDate(transaction: incomes[i])
                
                // Asegurar que el estado de completado no ha cambiado
                incomes[i].isCompleted = estaCompletado
                
                // Mostrar resultado
                if let nextDate = incomes[i].nextAppearanceDate {
                    print("  • Nueva fecha de próxima aparición: \(formatter.string(from: nextDate)) (Estado: \(estadoActual))")
                } else {
                    print("  • No se pudo calcular una fecha válida")
                }
            }
        }
        
        // Guardar los cambios para cada tipo de transacción
        StorageManager.shared.saveExpenses(expenses)
        StorageManager.shared.saveSubscriptions(subscriptions)
        StorageManager.shared.saveIncomes(incomes)
        
        // Forzar la actualización de la interfaz
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("FinanceViewModel: Recálculo de fechas completado - Se ha respetado el estado de cada elemento")
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
        print("FinanceViewModel: Obteniendo ingresos filtrados - showTips: \(showTips)")
        
        // Primero recalcular las propiedades pendientes para asegurar que estén actualizadas
        let now = Date()
        let pendingIncomes = incomes.filter { !$0.isCompleted && (!($0.startDate != nil && $0.startDate! > now)) }
        print("FinanceViewModel: Ingresos pendientes: \(pendingIncomes.count)")
        
        // Si showTips es true, mostrar todos los ingresos
        if showTips {
            print("FinanceViewModel: Devolviendo todos los ingresos (\(incomes.count))")
            return incomes
        } else {
            // Filtrar excluyendo las transacciones con concepto "Propinas" o tipo ".tips"
            let filteredList = incomes.filter { $0.concept != "Propinas" && $0.type != .tips }
            print("FinanceViewModel: Devolviendo ingresos filtrados sin propinas (\(filteredList.count))")
            return filteredList
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
        print("FinanceViewModel: Cargados \(customPaymentMethods.count) métodos de pago personalizados")
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
        // Cargar los métodos con el orden actual
        let orderedMethods = StorageManager.shared.loadMethodsOrder()
        
        if !orderedMethods.isEmpty {
            // Si tenemos un orden guardado, lo usamos directamente
            print("FinanceViewModel: Usando orden de métodos guardado: \(orderedMethods.count) métodos")
            return orderedMethods
        }
        
        // Si no hay orden guardado, seguimos el método tradicional
        // Comenzar con los métodos predefinidos
        var allMethods = PaymentMethod.allCases
            .map { $0.rawValue }
        
        // Añadir los personalizados manteniendo su orden original
        for method in customPaymentMethods {
            if !allMethods.contains(method) {
                allMethods.append(method)
            }
        }
        
        print("FinanceViewModel: Usando orden de métodos predeterminado: \(allMethods.count) métodos")
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
        // Cargar las categorías con el orden actual
        let orderedCategories = StorageManager.shared.loadCategoriesOrder()
        
        if !orderedCategories.isEmpty {
            // Si tenemos un orden guardado, lo usamos directamente
            print("FinanceViewModel: Usando orden de categorías guardado: \(orderedCategories.count) categorías")
            return orderedCategories
        }
        
        // Si no hay orden guardado, seguimos el método tradicional
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
        
        print("FinanceViewModel: Usando orden de categorías predeterminado: \(allCategories.count) categorías")
        return allCategories
    }
    
    // Funciones para gestionar notificaciones de gastos
    func scheduleExpenseNotifications() {
        print("FinanceViewModel: Programando notificaciones para gastos pendientes")
        
        // Primero, cancelar notificaciones existentes para evitar duplicados
        NotificationManager.shared.cancelAllExpenseNotifications()
        
        // Verificar que las notificaciones están habilitadas en la configuración
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled")
        guard notificationsEnabled else {
            print("FinanceViewModel: Las notificaciones de gastos están desactivadas")
            return
        }
        
        // Verificar permisos de notificación
        NotificationManager.shared.checkPermission { authorized in
            guard authorized else {
                print("FinanceViewModel: No hay permiso para enviar notificaciones")
                return
            }
            
            // Filtrar los gastos pendientes que tienen fecha de próximo cargo
            let pendingExpenses = self.expenses.filter { 
                !$0.isCompleted && 
                $0.nextAppearanceDate != nil && 
                !$0.concept.isEmpty
            }
            
            print("FinanceViewModel: Encontrados \(pendingExpenses.count) gastos pendientes para notificaciones")
            
            // Programar solo la notificación resumen
            NotificationManager.shared.scheduleSummaryExpenseNotification(expenses: pendingExpenses)
        }
    }
    
    // Para actualizar el estado de notificaciones cuando se modifica un gasto
    func updateExpenseNotifications() {
        // Solo reprogramar si las notificaciones están habilitadas
        if UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled") {
            // Reprogramar todas las notificaciones
            scheduleExpenseNotifications()
        }
    }
    
    // Para cancelar notificaciones de un gasto específico (útil cuando se elimina un gasto)
    func cancelExpenseNotifications(for expenseId: UUID) {
        NotificationManager.shared.cancelExpenseNotifications(transactionId: expenseId.uuidString)
    }
    
    // Función para depuración: imprime el próximo gasto pendiente y su fecha de próximo cargo
    func printNextPendingExpense() {
        let now = Date()
        let pending = expenses.filter { !$0.isCompleted && ($0.nextAppearanceDate ?? now) > now }
        if let next = pending.sorted(by: { ($0.nextAppearanceDate ?? now) < ($1.nextAppearanceDate ?? now) }).first,
           let fecha = next.nextAppearanceDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = "d MMMM yyyy"
            print("El próximo gasto pendiente es '\(next.concept)' el \(formatter.string(from: fecha))")
        } else {
            print("No hay gastos pendientes futuros.")
        }
    }
    
    // MARK: - Limpieza de archivos backup
    
    func cleanBackupFiles() -> (success: Bool, message: String?) {
        print("FinanceViewModel: Iniciando limpieza de archivos backup")
        
        let result = StorageManager.shared.cleanBackupFiles()
        
        print("FinanceViewModel: Resultado de limpieza - Éxito: \(result.success), Archivos eliminados: \(result.filesDeleted)")
        
        return (result.success, result.message)
    }
} 
