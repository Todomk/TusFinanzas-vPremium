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
         nextAppearanceDate: Date? = nil) {
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
            // Día de referencia a mantener
            let dayComponents = calendar.dateComponents([.day], from: start)
            let dayToKeep = dayComponents.day ?? 1
            print("Día a mantener: \(dayToKeep)")
            
            // Si la fecha de inicio es en el futuro, calcular la siguiente según periodicidad
            // comenzando DESDE esa fecha de inicio (no desde hoy)
            if start > now {
                print("Caso 1: Fecha inicio en el futuro")
                var result: Date?
                
                switch periodicity {
                case .weekly:
                    print("Periodicidad semanal: Devolviendo misma fecha de inicio")
                    result = start // Para semanal, la primera aparición es la fecha de inicio
                case .monthly:
                    print("Periodicidad mensual: Devolviendo misma fecha de inicio")
                    result = start // Para mensual, la primera aparición es la fecha de inicio
                case .bimonthly:
                    print("Periodicidad bimensual: Calculando fecha a 2 meses")
                    result = calendar.date(byAdding: .month, value: 2, to: start)
                case .quarterly:
                    print("Periodicidad trimestral: Calculando fecha a 3 meses")
                    result = calendar.date(byAdding: .month, value: 3, to: start)
                case .semiannual:
                    print("Periodicidad semestral: Calculando fecha a 6 meses")
                    result = calendar.date(byAdding: .month, value: 6, to: start)
                case .annual:
                    print("Periodicidad anual: Calculando fecha a 1 año")
                    result = calendar.date(byAdding: .year, value: 1, to: start)
                case .biannual:
                    print("Periodicidad bianual: Calculando fecha a 2 años")
                    result = calendar.date(byAdding: .year, value: 2, to: start)
                }
                
                if let date = result {
                    print("Próxima aparición calculada: \(date.debugDescription())")
                } else {
                    print("Error: No se pudo calcular la próxima aparición")
                }
                return result
            }
            
            // Si la fecha de inicio es pasada, calcular la próxima según periodicidad
            // asegurando mantener el mismo día del mes
            print("Caso 2: Fecha inicio en el pasado")
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
                if baseDate <= now {
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
            if let next = nextDate, next < now {
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
               lhs.gpCategory == rhs.gpCategory
    }
} 