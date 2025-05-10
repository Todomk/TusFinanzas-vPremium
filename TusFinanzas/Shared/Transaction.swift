import Foundation

// Añadir esta extensión para ayudar en la depuración
extension Date {
    func debugDescription() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
}

enum TransactionType: String, Codable {
    case income
    case expense
    case subscription
    case tips = "propinas"
    case gp = "GP"
}

enum Periodicity: String, CaseIterable, Codable {
    case weekly = "Semanal"
    case monthly = "Mensual"
    case bimonthly = "Bimensual"
    case quarterly = "Trimestral"
    case semiannual = "Semestral"
    case annual = "Anual"
    case biannual = "Bianual"
    
    // Método para obtener solo las periodicidades válidas para gastos
    static var expensePeriodicities: [Periodicity] {
        return [.monthly, .bimonthly, .quarterly, .semiannual, .annual]
    }
    
    // Método para verificar si es una periodicidad válida para gastos
    var isValidForExpense: Bool {
        return Periodicity.expensePeriodicities.contains(self)
    }
}

enum WeekDay: Int, CaseIterable, Codable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7
    
    var description: String {
        switch self {
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sábado"
        case .sunday: return "Domingo"
        }
    }
}

enum PaymentType: String, CaseIterable, Codable {
    case manual = "Manual"
    case automatic = "Automático"
}

enum PaymentMethod: String, CaseIterable, Codable {
    case cash = "Efectivo"
    case bank = "Transferencia"
    case card = "Tarjeta"
    case check = "Talón"
    case directDebit = "Domiciliación"
    case bizum = "Bizum"
}

enum AutomaticPaymentOption: String, CaseIterable, Codable {
    case specificDay = "Un día concreto del mes"
    case lastWorkday = "Último día laboral del mes"
    case firstWorkday = "Primer día laboral del mes"
    case specificWeekDay = "Un día específico de la semana"
    case lastWorkDayOfWeek = "Último día laboral de la semana"
}

enum GPCategory: String, CaseIterable, Codable {
    case restauracion = "Restauración"
    case gasolina = "Gasolina"
    case supermercados = "Supermercados y Alimentación"
    case ropa = "Ropa"
    case compraOnline = "Compra Online"
    case salud = "Salud"
    case belleza = "Belleza"
    case ocio = "Ocio"
    case otros = "Otros"
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var concept: String
    var isCompleted: Bool
    var type: TransactionType
    var periodicity: Periodicity
    var paymentType: PaymentType
    var paymentMethod: PaymentMethod
    var paymentDay: Int?
    var weekDay: WeekDay?
    var automaticPaymentOption: AutomaticPaymentOption?
    var date: Date
    var startDate: Date?
    var endDate: Date?
    var lastResetDate: Date?
    var weeklyAmounts: [Date: Double]?
    var gpCategory: GPCategory?
    var nextAppearanceDate: Date?
    var customPaymentMethod: String?
    var customGPCategory: String?
    var appearanceMonths: [Date]? // Array con las fechas de aparición de la transacción
    
    init(amount: Double, 
         concept: String, 
         isCompleted: Bool = false,
         type: TransactionType,
         periodicity: Periodicity = .monthly,
         paymentType: PaymentType = .manual,
         paymentMethod: PaymentMethod = .bank,
         paymentDay: Int? = nil,
         weekDay: WeekDay? = nil,
         automaticPaymentOption: AutomaticPaymentOption? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         lastResetDate: Date? = nil,
         weeklyAmounts: [Date: Double]? = nil,
         gpCategory: GPCategory? = nil,
         nextAppearanceDate: Date? = nil,
         customPaymentMethod: String? = nil,
         customGPCategory: String? = nil) {
        self.id = UUID()
        self.amount = amount
        self.concept = concept
        self.isCompleted = isCompleted
        self.type = type
        self.periodicity = periodicity
        self.paymentType = paymentType
        self.paymentMethod = paymentMethod
        self.paymentDay = paymentDay
        self.weekDay = weekDay
        self.automaticPaymentOption = automaticPaymentOption
        self.date = Date()
        self.startDate = startDate
        self.endDate = endDate
        self.lastResetDate = lastResetDate
        self.weeklyAmounts = weeklyAmounts
        self.gpCategory = gpCategory
        
        // Si ya se proporciona la fecha de próxima aparición, usarla
        // De lo contrario, calcularla usando startDate y lastResetDate
        if let providedNextDate = nextAppearanceDate {
            self.nextAppearanceDate = providedNextDate
        } else {
            // Usar el método de cálculo para obtener la fecha de próxima aparición
            self.nextAppearanceDate = Self.calculateNextAppearanceDate(
                startDate: startDate,
                lastResetDate: lastResetDate,
                periodicity: periodicity
            )
        }
        
        self.customPaymentMethod = customPaymentMethod
        self.customGPCategory = customGPCategory
        
        // Calcular los meses de aparición según la periodicidad
        if let start = startDate {
            self.appearanceMonths = Self.calculateAppearanceMonths(
                startDate: start, 
                endDate: endDate, 
                periodicity: periodicity
            )
        } else {
            self.appearanceMonths = nil
        }
    }
    
    // Método para calcular la próxima fecha de aparición basado en startDate, lastResetDate y periodicidad
    static func calculateNextAppearanceDate(startDate: Date?, lastResetDate: Date?, periodicity: Periodicity) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        print("=== DEBUG CÁLCULO PRÓXIMA APARICIÓN ===")
        print("Fecha actual: \(now.debugDescription())")
        print("Periodicidad: \(periodicity.rawValue)")
        if let start = startDate {
            print("Fecha inicio: \(start.debugDescription())")
        } else {
            print("Fecha inicio: nil")
        }
        if let last = lastResetDate {
            print("Último reset: \(last.debugDescription())")
        } else {
            print("Último reset: nil")
        }
        
        // Si tiene startDate, utilizamos esa como referencia principal
        if let start = startDate {
            // Normalizar las fechas para comparar solo año, mes y día (sin hora)
            let normalizedStart = calendar.startOfDay(for: start)
            let normalizedNow = calendar.startOfDay(for: now)
            
            // Si la fecha de inicio es en el futuro, calcular la siguiente según periodicidad
            // comenzando DESDE esa fecha de inicio (no desde hoy)
            if normalizedStart >= normalizedNow {
                print("Caso 1: Fecha inicio en el futuro o hoy")
                // Si la fecha de inicio está en el futuro, la próxima aparición siempre es la fecha de inicio
                print("La fecha de inicio está en el futuro, devolviendo la misma fecha de inicio")
                print("Próxima aparición calculada: \(start.debugDescription())")
                return start
            }
            
            // Si la fecha de inicio es pasada, calcular la próxima según periodicidad
            // asegurando mantener el mismo día del mes
            print("Caso 2: Fecha inicio en el pasado")
            
            // Día de referencia a mantener
            let dayComponents = calendar.dateComponents([.day], from: start)
            let dayToKeep = dayComponents.day ?? 1
            print("Día a mantener: \(dayToKeep)")
            
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = dayToKeep
            
            // Obtener la fecha base con el día correcto
            guard var baseDate = calendar.date(from: components) else {
                print("Error: No se pudo crear la fecha base")
                return now
            }
            
            print("Fecha base creada: \(baseDate.debugDescription())")
            
            // Siempre avanzar al menos al próximo período, independientemente de si la fecha base
            // es anterior o posterior a hoy
            var result: Date?
            
            switch periodicity {
            case .weekly:
                // Para frecuencia semanal, avanzar 7 días desde hoy si la baseDate es en el pasado
                // Normalizar las fechas para comparar solo año, mes y día (sin hora)
                let normalizedBase = calendar.startOfDay(for: baseDate)
                let normalizedNow = calendar.startOfDay(for: now)
                
                if normalizedBase <= normalizedNow {
                    print("Periodicidad semanal con base <= hoy: Avanzando 7 días")
                    result = calendar.date(byAdding: .day, value: 7, to: baseDate)
                } else {
                    print("Periodicidad semanal con base > hoy: Usando fecha base")
                    result = baseDate
                }
            case .monthly:
                // Siempre avanzar al menos un mes
                print("Periodicidad mensual: Avanzando 1 mes desde fecha base")
                result = calendar.date(byAdding: .month, value: 1, to: baseDate)
            case .bimonthly:
                print("Periodicidad bimensual: Avanzando 2 meses desde fecha base")
                result = calendar.date(byAdding: .month, value: 2, to: baseDate)
            case .quarterly:
                print("Periodicidad trimestral: Avanzando 3 meses desde fecha base")
                result = calendar.date(byAdding: .month, value: 3, to: baseDate)
            case .semiannual:
                print("Periodicidad semestral: Avanzando 6 meses desde fecha base")
                result = calendar.date(byAdding: .month, value: 6, to: baseDate)
            case .annual:
                print("Periodicidad anual: Avanzando 1 año desde fecha base")
                result = calendar.date(byAdding: .year, value: 1, to: baseDate)
            case .biannual:
                print("Periodicidad bianual: Avanzando 2 años desde fecha base")
                result = calendar.date(byAdding: .year, value: 2, to: baseDate)
            }
            
            if let date = result {
                print("Próxima aparición calculada: \(date.debugDescription())")
            } else {
                print("Error: No se pudo calcular la próxima aparición")
            }
            return result
        }
        
        // Si tiene lastResetDate, calcular desde ahí
        if let lastReset = lastResetDate {
            print("Caso 3: Usando lastResetDate")
            var nextDate: Date?
            
            // Calcular próxima fecha según periodicidad
            switch periodicity {
            case .weekly:
                nextDate = calendar.date(byAdding: .day, value: 7, to: lastReset)
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: lastReset)
            case .bimonthly:
                nextDate = calendar.date(byAdding: .month, value: 2, to: lastReset)
            case .quarterly:
                nextDate = calendar.date(byAdding: .month, value: 3, to: lastReset)
            case .semiannual:
                nextDate = calendar.date(byAdding: .month, value: 6, to: lastReset)
            case .annual:
                nextDate = calendar.date(byAdding: .year, value: 1, to: lastReset)
            case .biannual:
                nextDate = calendar.date(byAdding: .year, value: 2, to: lastReset)
            }
            
            // Si la próxima fecha es anterior a hoy, calcular la siguiente correspondiente
            if let next = nextDate {
                // Normalizar las fechas para comparar solo año, mes y día (sin hora)
                let normalizedNext = calendar.startOfDay(for: next)
                let normalizedNow = calendar.startOfDay(for: now)
                
                if normalizedNext < normalizedNow {
                    print("La próxima fecha calculada es anterior a hoy, recalculando...")
                    // Calcular cuántas periodicidades han pasado desde esa fecha
                    let components: DateComponents
                    var unitsToAdd: Int = 0
                    
                    switch periodicity {
                    case .weekly:
                        components = calendar.dateComponents([.day], from: lastReset, to: now)
                        let daysPassed = components.day ?? 0
                        unitsToAdd = (daysPassed / 7 + 1) * 7 // Asegurar que sea múltiplo de 7
                        print("Días pasados: \(daysPassed), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .day, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .monthly:
                        components = calendar.dateComponents([.month], from: lastReset, to: now)
                        unitsToAdd = (components.month ?? 0) + 1
                        print("Meses pasados: \(components.month ?? 0), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .month, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .bimonthly:
                        components = calendar.dateComponents([.month], from: lastReset, to: now)
                        let monthsPassed = components.month ?? 0
                        unitsToAdd = (monthsPassed / 2 + 1) * 2 // Asegurar que sea múltiplo de 2
                        print("Meses pasados: \(monthsPassed), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .month, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .quarterly:
                        components = calendar.dateComponents([.month], from: lastReset, to: now)
                        let monthsPassed = components.month ?? 0
                        unitsToAdd = (monthsPassed / 3 + 1) * 3 // Asegurar que sea múltiplo de 3
                        print("Meses pasados: \(monthsPassed), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .month, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .semiannual:
                        components = calendar.dateComponents([.month], from: lastReset, to: now)
                        let monthsPassed = components.month ?? 0
                        unitsToAdd = (monthsPassed / 6 + 1) * 6 // Asegurar que sea múltiplo de 6
                        print("Meses pasados: \(monthsPassed), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .month, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .annual:
                        components = calendar.dateComponents([.year], from: lastReset, to: now)
                        unitsToAdd = (components.year ?? 0) + 1
                        print("Años pasados: \(components.year ?? 0), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .year, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    case .biannual:
                        components = calendar.dateComponents([.year], from: lastReset, to: now)
                        let yearsPassed = components.year ?? 0
                        unitsToAdd = (yearsPassed / 2 + 1) * 2 // Asegurar que sea múltiplo de 2
                        print("Años pasados: \(yearsPassed), unidades a añadir: \(unitsToAdd)")
                        let result = calendar.date(byAdding: .year, value: unitsToAdd, to: lastReset)
                        if let date = result {
                            print("Próxima aparición recalculada: \(date.debugDescription())")
                        }
                        return result
                    }
                }
            }
            
            if let date = nextDate {
                print("Próxima aparición desde lastResetDate: \(date.debugDescription())")
            }
            return nextDate
        }
        
        // Si no tiene ni lastResetDate ni startDate, usar un mes después de la fecha actual
        print("Caso 4: No hay fecha de inicio ni último reset. Usando un mes desde hoy")
        let result = calendar.date(byAdding: .month, value: 1, to: now)
        if let date = result {
            print("Próxima aparición por defecto: \(date.debugDescription())")
        }
        return result
    }
    
    // Método para calcular los meses de aparición según la periodicidad
    static func calculateAppearanceMonths(startDate: Date, endDate: Date?, periodicity: Periodicity) -> [Date] {
        let calendar = Calendar.current
        var appearanceDates: [Date] = []
        
        // Normalizar la fecha de inicio para que sea el primer día del mes (sin horas/minutos/segundos)
        var components = calendar.dateComponents([.year, .month], from: startDate)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let startMonth = calendar.date(from: components) else {
            print("Error al normalizar la fecha de inicio para los meses de aparición")
            return []
        }
        
        // Añadir el mes de inicio como primer mes de aparición
        appearanceDates.append(startMonth)
        
        // Determinar la fecha final de cálculo (dos años desde hoy si no hay fecha final)
        let finalDate: Date
        if let end = endDate {
            // Normalizar la fecha final a nivel de mes
            var endComponents = calendar.dateComponents([.year, .month], from: end)
            endComponents.day = 1
            finalDate = calendar.date(from: endComponents) ?? end
        } else {
            // Si no hay fecha final, calcular hasta dos años desde hoy para tener suficientes apariciones
            let twoYearsLater = calendar.date(byAdding: .year, value: 2, to: Date()) ?? Date()
            var futureComponents = calendar.dateComponents([.year, .month], from: twoYearsLater)
            futureComponents.day = 1
            finalDate = calendar.date(from: futureComponents) ?? twoYearsLater
        }
        
        // Variable para ir avanzando en el cálculo
        var currentDate = startMonth
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        print("===== CALCULANDO MESES DE APARICIÓN =====")
        print("Periodicidad: \(periodicity.rawValue)")
        print("Fecha inicio: \(formatter.string(from: startMonth))")
        print("Fecha límite: \(formatter.string(from: finalDate))")
        
        // Calcular los meses de aparición según la periodicidad
        while true {
            var nextDate: Date
            var increment = 1
            
            switch periodicity {
            case .weekly:
                // Para periodicidad semanal, aparece todos los meses (12 meses al año)
                increment = 1
            case .monthly:
                // Aparece todos los meses (12 meses al año)
                increment = 1
            case .bimonthly:
                // Aparece cada 2 meses (6 meses al año)
                increment = 2
            case .quarterly:
                // Aparece cada 3 meses exactamente (4 meses al año)
                increment = 3
                print("Calculando mes trimestral: incremento = 3")
            case .semiannual:
                // Aparece cada 6 meses (2 meses al año)
                increment = 6
            case .annual:
                // Aparece cada 12 meses (1 mes al año)
                increment = 12
            case .biannual:
                // Aparece cada 24 meses (1 mes cada 2 años)
                increment = 24
            }
            
            // Verificar que para periodicidad trimestral se incremente exactamente 3 meses
            if periodicity == .quarterly {
                var newComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                // Avanzar 3 meses exactos
                if let month = newComponents.month {
                    let newMonth = month + 3
                    if newMonth > 12 {
                        newComponents.month = newMonth - 12
                        newComponents.year! += 1
                    } else {
                        newComponents.month = newMonth
                    }
                }
                
                nextDate = calendar.date(from: newComponents) ?? calendar.date(byAdding: .month, value: 3, to: currentDate)!
                print("Fecha trimestral calculada: \(formatter.string(from: nextDate))")
            } else {
                // Calcular la siguiente fecha para otras periodicidades
                nextDate = calendar.date(byAdding: .month, value: increment, to: currentDate) ?? currentDate
            }
            
            // Si la fecha calculada es posterior a la fecha final, salir del bucle
            if nextDate > finalDate {
                break
            }
            
            // Añadir la fecha calculada a la lista de apariciones
            appearanceDates.append(nextDate)
            print("Añadiendo mes: \(formatter.string(from: nextDate))")
            
            // Avanzar a la siguiente fecha
            currentDate = nextDate
        }
        
        print("Total meses calculados: \(appearanceDates.count)")
        print("=====")
        
        return appearanceDates
    }
    
    // Método estático para probar el cálculo de la fecha de próxima aparición
    static func testNextAppearanceCalculation() {
        print("\n===== PRUEBA DE CÁLCULO DE PRÓXIMA APARICIÓN =====")
        
        // Crear un formatter para mostrar fechas legibles
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        dateFormatter.locale = Locale(identifier: "es_ES")
        
        // Establecer la fecha de inicio (2 de mayo de 2025)
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 5
        dateComponents.day = 2
        
        guard let startDate = calendar.date(from: dateComponents) else {
            print("Error al crear la fecha de inicio para prueba")
            return
        }
        
        print("Fecha de inicio: \(dateFormatter.string(from: startDate))")
        
        // Probar para cada periodicidad
        for periodicity in Periodicity.allCases {
            print("\nPeriodicidad: \(periodicity.rawValue)")
            
            if let nextDate = calculateNextAppearanceDate(
                startDate: startDate, 
                lastResetDate: nil, 
                periodicity: periodicity
            ) {
                print("Próxima aparición: \(dateFormatter.string(from: nextDate))")
                
                // Calcular la diferencia en tiempo
                let diffComponents = calendar.dateComponents([.day, .month, .year], from: startDate, to: nextDate)
                print("Diferencia: \(diffComponents.year ?? 0) años, \(diffComponents.month ?? 0) meses, \(diffComponents.day ?? 0) días")
            } else {
                print("Error: No se pudo calcular la próxima aparición")
            }
        }
        
        print("===== FIN DE PRUEBA =====\n")
    }
    
    // Método estático para probar el cálculo de los meses de aparición
    static func testAppearanceMonthsCalculation() {
        print("\n===== PRUEBA DE CÁLCULO DE MESES DE APARICIÓN =====")
        
        // Crear un formatter para mostrar fechas legibles
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        dateFormatter.locale = Locale(identifier: "es_ES")
        
        // Establecer la fecha de inicio (2 de mayo de 2023)
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2023
        dateComponents.month = 5
        dateComponents.day = 2
        
        guard let startDate = calendar.date(from: dateComponents) else {
            print("Error al crear la fecha de inicio para prueba")
            return
        }
        
        // Establecer la fecha de fin (31 de diciembre de 2023)
        var endDateComponents = DateComponents()
        endDateComponents.year = 2023
        endDateComponents.month = 12
        endDateComponents.day = 31
        
        guard let endDate = calendar.date(from: endDateComponents) else {
            print("Error al crear la fecha de fin para prueba")
            return
        }
        
        print("Fecha de inicio: \(dateFormatter.string(from: startDate))")
        print("Fecha de fin: \(dateFormatter.string(from: endDate))")
        
        // Probar para cada periodicidad
        for periodicity in Periodicity.allCases {
            print("\nPeriodicidad: \(periodicity.rawValue)")
            
            let appearanceMonths = calculateAppearanceMonths(
                startDate: startDate,
                endDate: endDate,
                periodicity: periodicity
            )
            
            print("Fechas de aparición:")
            for (index, date) in appearanceMonths.enumerated() {
                print("\(index + 1). \(dateFormatter.string(from: date))")
            }
            
            print("Total meses de aparición: \(appearanceMonths.count)")
        }
        
        print("===== FIN DE PRUEBA =====\n")
    }
}

extension Transaction: Equatable {
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.id == rhs.id &&
               lhs.amount == rhs.amount &&
               lhs.concept == rhs.concept &&
               lhs.isCompleted == rhs.isCompleted &&
               lhs.type == rhs.type &&
               lhs.periodicity == rhs.periodicity &&
               lhs.paymentType == rhs.paymentType &&
               lhs.paymentMethod == rhs.paymentMethod &&
               lhs.paymentDay == rhs.paymentDay &&
               lhs.weekDay == rhs.weekDay &&
               lhs.automaticPaymentOption == rhs.automaticPaymentOption &&
               Calendar.current.isDate(lhs.date, equalTo: rhs.date, toGranularity: .second) &&
               (lhs.startDate.map { lhsDate in
                   rhs.startDate.map { rhsDate in
                       Calendar.current.isDate(lhsDate, equalTo: rhsDate, toGranularity: .second)
                   } ?? false
               } ?? (rhs.startDate == nil)) &&
               (lhs.endDate.map { lhsDate in
                   rhs.endDate.map { rhsDate in
                       Calendar.current.isDate(lhsDate, equalTo: rhsDate, toGranularity: .second)
                   } ?? false
               } ?? (rhs.endDate == nil)) &&
               (lhs.lastResetDate.map { lhsDate in
                   rhs.lastResetDate.map { rhsDate in
                       Calendar.current.isDate(lhsDate, equalTo: rhsDate, toGranularity: .second)
                   } ?? false
               } ?? (rhs.lastResetDate == nil)) &&
               (lhs.nextAppearanceDate.map { lhsDate in
                   rhs.nextAppearanceDate.map { rhsDate in
                       Calendar.current.isDate(lhsDate, equalTo: rhsDate, toGranularity: .second)
                   } ?? false
               } ?? (rhs.nextAppearanceDate == nil)) &&
               lhs.weeklyAmounts?.map { (date, amount) in
                   rhs.weeklyAmounts?.contains { (rhsDate, rhsAmount) in
                       Calendar.current.isDate(date, equalTo: rhsDate, toGranularity: .second) &&
                       amount == rhsAmount
                   } ?? false
               }.allSatisfy { $0 } ?? (rhs.weeklyAmounts == nil) &&
               lhs.gpCategory == rhs.gpCategory &&
               lhs.customPaymentMethod == rhs.customPaymentMethod &&
               lhs.customGPCategory == rhs.customGPCategory
    }
} 