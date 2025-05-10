import Foundation
import UserNotifications
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Categorías de notificaciones
    enum NotificationCategory: String {
        case expenseReminder = "EXPENSE_REMINDER"
    }
    
    // Identificadores de notificaciones
    enum NotificationIdentifier: String {
        case expenseDayBefore = "expense_day_before"
        case expenseSameDay = "expense_same_day"
        
        // Función para generar un ID único por transacción
        func forTransaction(_ transactionId: String) -> String {
            return "\(self.rawValue)_\(transactionId)"
        }
    }
    
    // Obtener la hora configurada para las notificaciones
    private func getNotificationHour() -> Int {
        return UserDefaults.standard.integer(forKey: "notificationHour")
    }
    
    // Obtener los minutos configurados para las notificaciones
    private func getNotificationMinute() -> Int {
        return UserDefaults.standard.integer(forKey: "notificationMinute")
    }
    
    // Obtener la hora configurada para las notificaciones del día anterior
    private func getDayBeforeNotificationHour() -> Int {
        return UserDefaults.standard.integer(forKey: "dayBeforeNotificationHour")
    }
    
    // Obtener los minutos configurados para las notificaciones del día anterior
    private func getDayBeforeNotificationMinute() -> Int {
        return UserDefaults.standard.integer(forKey: "dayBeforeNotificationMinute")
    }
    
    // Solicitar permiso para mostrar notificaciones
    func requestPermission(completion: @escaping (Bool) -> Void) {
        print("NotificationManager: Solicitando permisos de notificación...")
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("NotificationManager: Error al solicitar permisos: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("NotificationManager: Permisos \(granted ? "concedidos" : "denegados")")
            
            // Verificar el estado actual de los permisos
            self.notificationCenter.getNotificationSettings { settings in
                print("NotificationManager: Estado actual de permisos:")
                print("- Authorization Status: \(settings.authorizationStatus.rawValue)")
                print("- Alert Setting: \(settings.alertSetting.rawValue)")
                print("- Sound Setting: \(settings.soundSetting.rawValue)")
                print("- Badge Setting: \(settings.badgeSetting.rawValue)")
                
                completion(granted)
            }
        }
    }
    
    // Verificar si hay permisos de notificación
    func checkPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            completion(isAuthorized)
        }
    }
    
    // Programar notificación para gastos pendientes (un día antes)
    func scheduleExpenseNotificationDayBefore(transactionId: String, concept: String, amount: Double, date: Date, periodicity: String, paymentMethod: String) {
        print("NotificationManager: Programando notificación para el día anterior - Concepto: \(concept), Fecha: \(date)")
        
        // Verificar permisos primero
        notificationCenter.getNotificationSettings { settings in
            print("NotificationManager: Estado actual de permisos:")
            print("- Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("- Alert Setting: \(settings.alertSetting.rawValue)")
            print("- Sound Setting: \(settings.soundSetting.rawValue)")
            print("- Badge Setting: \(settings.badgeSetting.rawValue)")
            
            guard settings.authorizationStatus == .authorized else {
                print("NotificationManager: No hay permisos para enviar notificaciones")
                return
            }
            
            // Calcular la fecha un día antes
            guard let dayBeforeDate = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
                print("NotificationManager: Error calculando la fecha para el día anterior")
                return
            }
            
            // Verificar que la fecha es futura
            let now = Date()
            if dayBeforeDate <= now {
                print("NotificationManager: La fecha del día anterior (\(dayBeforeDate)) no es futura, no se programará la notificación")
                return
            }
            
            // Obtener la hora y minutos configurados para las notificaciones del día anterior
            let notificationHour = self.getDayBeforeNotificationHour()
            let notificationMinute = self.getDayBeforeNotificationMinute()
            
            print("NotificationManager: Hora configurada para notificación del día anterior: \(notificationHour):\(notificationMinute)")
            
            // Crear un componente de fecha para la hora y minuto configurados del día anterior
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dayBeforeDate)
            dateComponents.hour = notificationHour
            dateComponents.minute = notificationMinute
            print("[DEBUG] DateComponents para día anterior: \(dateComponents)")
            
            // LOG: Mostrar la fecha y hora exacta del trigger
            if let triggerDate = Calendar.current.date(from: dateComponents) {
                print("[LOG] La notificación del día anterior se programará para: \(triggerDate)")
            }
            
            // Formatear día y mes en minúsculas
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "es_ES")
            dateFormatter.dateFormat = "d MMMM"
            let diaMes = dateFormatter.string(from: date).lowercased()

            // Formatear importe
            let importe = String(format: "%.2f", amount)

            // Formatear periodicidad y método de pago en minúsculas
            let periodicidadMin = periodicity.lowercased()
            let metodoPagoMin = paymentMethod.lowercased()

            // Construir el mensaje
            let mensaje = "mañana día: \(diaMes.capitalized) se cargará el recibo \(periodicidadMin) correspondiente al concepto: \(concept.capitalized) por importe de: \(importe)€ por el método de pago: \(metodoPagoMin.capitalized)."
            
            // Crear el contenido de la notificación
            let content = UNMutableNotificationContent()
            content.title = "Recordatorio de gasto para mañana"
            content.body = mensaje
            content.sound = UNNotificationSound.default
            content.badge = 1
            content.categoryIdentifier = NotificationCategory.expenseReminder.rawValue
            
            // Crear el disparador con la fecha calculada
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            print("[DEBUG] Trigger para día anterior: \(trigger)")
            print("[LOG] Contenido de la notificación: \(mensaje)")
            
            // Crear la solicitud de notificación
            let identifier = NotificationIdentifier.expenseDayBefore.forTransaction(transactionId)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // Programar la notificación
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("NotificationManager: Error al programar notificación para el día anterior: \(error.localizedDescription)")
                } else {
                    print("NotificationManager: Notificación programada para el día anterior (\(dayBeforeDate)) a las \(notificationHour):\(notificationMinute): \(concept)")
                    
                    // Verificar que la notificación se programó correctamente
                    self.verifyNotificationScheduled(identifier: identifier) { scheduled in
                        if scheduled {
                            print("NotificationManager: Verificación exitosa - Notificación programada correctamente")
                        } else {
                            print("NotificationManager: Error - La notificación no se programó correctamente")
                        }
                    }
                }
                // Mostrar todas las notificaciones pendientes
                self.printPendingNotifications()
                self.updateAppBadgeWithPendingNotifications()
            }
        }
    }
    
    // Programar notificación para gastos pendientes (mismo día)
    func scheduleExpenseNotificationSameDay(transactionId: String, concept: String, amount: Double, date: Date, periodicity: String, paymentMethod: String) {
        print("NotificationManager: Programando notificación para el mismo día - Concepto: \(concept), Fecha: \(date)")
        
        // Verificar que la fecha es futura
        let now = Date()
        if date <= now {
            print("NotificationManager: La fecha (\(date)) no es futura, no se programará la notificación")
            return
        }
        
        // Obtener la hora y minutos configurados para las notificaciones
        let notificationHour = getNotificationHour()
        let notificationMinute = getNotificationMinute()
        
        // Crear un componente de fecha para la hora y minuto configurados del mismo día
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = notificationHour
        dateComponents.minute = notificationMinute
        print("[DEBUG] DateComponents para mismo día: \(dateComponents)")
        
        // LOG: Mostrar la fecha y hora exacta del trigger
        if let triggerDate = Calendar.current.date(from: dateComponents) {
            print("[LOG] La notificación del mismo día se programará para: \(triggerDate)")
        }
        
        // Formatear día y mes en minúsculas
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "es_ES")
        dateFormatter.dateFormat = "d MMMM"
        let diaMes = dateFormatter.string(from: date).lowercased()

        // Formatear importe
        let importe = String(format: "%.2f", amount)

        // Formatear periodicidad y método de pago en minúsculas
        let periodicidadMin = periodicity.lowercased()
        let metodoPagoMin = paymentMethod.lowercased()

        // Construir el mensaje
        let mensaje = "hoy, día: \(diaMes.capitalized) se cargará el recibo \(periodicidadMin) correspondiente al concepto: \(concept.capitalized) por importe de: \(importe)€ por el método de pago: \(metodoPagoMin.capitalized)."
        
        // Crear el contenido de la notificación
        let content = UNMutableNotificationContent()
        content.title = "Recordatorio de gasto para hoy"
        content.body = mensaje
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = NotificationCategory.expenseReminder.rawValue
        
        // Crear el disparador con la fecha calculada
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        print("[DEBUG] Trigger para mismo día: \(trigger)")
        print("[LOG] Contenido de la notificación: \(mensaje)")
        
        // Crear la solicitud de notificación
        let identifier = NotificationIdentifier.expenseSameDay.forTransaction(transactionId)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Programar la notificación
        notificationCenter.add(request) { error in
            if let error = error {
                print("NotificationManager: Error al programar notificación para el mismo día: \(error.localizedDescription)")
            } else {
                print("NotificationManager: Notificación programada para el mismo día (\(date)) a las \(notificationHour):\(notificationMinute): \(concept)")
                
                // Verificar que la notificación se programó correctamente
                self.verifyNotificationScheduled(identifier: identifier) { scheduled in
                    if scheduled {
                        print("NotificationManager: Verificación exitosa - Notificación programada correctamente")
                    } else {
                        print("NotificationManager: Error - La notificación no se programó correctamente")
                    }
                }
            }
            // Mostrar todas las notificaciones pendientes
            self.printPendingNotifications()
            self.updateAppBadgeWithPendingNotifications()
        }
    }
    
    // Mostrar todas las notificaciones pendientes
    func printPendingNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            print("[DEBUG] Notificaciones pendientes:")
            for req in requests {
                print("- \(req.identifier): \(String(describing: req.trigger))")
            }
        }
    }
    
    // Verificar si una notificación específica está programada
    private func verifyNotificationScheduled(identifier: String, completion: @escaping (Bool) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            let isScheduled = requests.contains { $0.identifier == identifier }
            completion(isScheduled)
        }
    }
    
    // Cancelar todas las notificaciones de gastos pendientes
    func cancelAllExpenseNotifications() {
        print("NotificationManager: Cancelando todas las notificaciones de gastos pendientes")
        
        notificationCenter.getPendingNotificationRequests { requests in
            // Identificar las notificaciones de gastos pendientes
            let expenseNotificationIds = requests
                .filter { $0.content.categoryIdentifier == NotificationCategory.expenseReminder.rawValue }
                .map { $0.identifier }
            
            print("NotificationManager: Encontradas \(expenseNotificationIds.count) notificaciones para cancelar")
            
            // Cancelar las notificaciones identificadas
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: expenseNotificationIds)
            
            // Verificar que se cancelaron correctamente
            self.verifyNotificationsCancelled(identifiers: expenseNotificationIds) { allCancelled in
                if allCancelled {
                    print("NotificationManager: Todas las notificaciones se cancelaron correctamente")
                } else {
                    print("NotificationManager: Error - Algunas notificaciones no se cancelaron correctamente")
                }
                self.updateAppBadgeWithPendingNotifications()
            }
        }
    }
    
    // Verificar si todas las notificaciones se cancelaron correctamente
    private func verifyNotificationsCancelled(identifiers: [String], completion: @escaping (Bool) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            let remainingNotifications = requests.filter { identifiers.contains($0.identifier) }
            completion(remainingNotifications.isEmpty)
        }
    }
    
    // Cancelar notificaciones específicas para una transacción
    func cancelExpenseNotifications(transactionId: String) {
        let dayBeforeId = NotificationIdentifier.expenseDayBefore.forTransaction(transactionId)
        let sameDayId = NotificationIdentifier.expenseSameDay.forTransaction(transactionId)
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dayBeforeId, sameDayId])
        print("NotificationManager: Canceladas notificaciones para transacción \(transactionId)")
        self.updateAppBadgeWithPendingNotifications()
    }
    
    // Reprogramar todas las notificaciones existentes con las nuevas horas configuradas
    func rescheduleAllNotifications() {
        print("NotificationManager: Reprogramando todas las notificaciones con las nuevas horas configuradas")
        
        // Primero cancelar todas las notificaciones existentes
        cancelAllExpenseNotifications()
        
        // Luego, reprogramar todas las notificaciones pendientes
        // Esto se hará a través del FinanceViewModel que tiene acceso a todas las transacciones
        NotificationCenter.default.post(name: NSNotification.Name("RescheduleAllNotifications"), object: nil)
    }
    
    // Función de test para programar una notificación en 1 minuto
    func scheduleTestNotification() {
        print("[TEST] Programando notificación de prueba para 1 minuto en el futuro...")
        let content = UNMutableNotificationContent()
        content.title = "Notificación de prueba"
        content.body = "Esto es una notificación de prueba programada para 1 minuto en el futuro."
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let triggerDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: "test_notification_1min", content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                print("[TEST] Error al programar la notificación de prueba: \(error.localizedDescription)")
            } else {
                print("[TEST] Notificación de prueba programada para: \(triggerDate)")
                self.printPendingNotifications()
            }
        }
    }
    
    // Actualizar el badge de la app con el número de notificaciones pendientes de gastos SOLO de hoy y mañana
    func updateAppBadgeWithPendingNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

            let count = requests.filter { req in
                guard req.content.categoryIdentifier == NotificationCategory.expenseReminder.rawValue,
                      let trigger = req.trigger as? UNCalendarNotificationTrigger,
                      let triggerDate = trigger.nextTriggerDate() else {
                    return false
                }
                let triggerDay = calendar.startOfDay(for: triggerDate)
                return triggerDay == today || triggerDay == tomorrow
            }.count

            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
    
    // Programar una notificación resumen con todos los gastos de hoy y de mañana
    func scheduleSummaryExpenseNotification(expenses: [Transaction]) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Filtrar gastos pendientes para hoy y mañana
        let todayExpenses = expenses.filter {
            guard let date = $0.nextAppearanceDate else { return false }
            return !$0.isCompleted && calendar.isDate(date, inSameDayAs: today)
        }
        let tomorrowExpenses = expenses.filter {
            guard let date = $0.nextAppearanceDate else { return false }
            return !$0.isCompleted && calendar.isDate(date, inSameDayAs: tomorrow)
        }

        // Construir el mensaje completo
        var body = ""
        var totalHoy: Double = 0
        var totalManana: Double = 0
        var resumenHoy: [String] = []
        var resumenManana: [String] = []
        
        // Procesar gastos de hoy (solo para la notificación del mismo día)
        if !todayExpenses.isEmpty {
            for exp in todayExpenses {
                let concepto = exp.concept.isEmpty ? "N/A" : exp.concept.capitalized
                let importe = exp.amount > 0 ? String(format: "%.2f", exp.amount) : "N/A"
                resumenHoy.append("\(concepto) (\(importe)€)")
                totalHoy += exp.amount
            }
        }
        
        // Procesar gastos de mañana
        if !tomorrowExpenses.isEmpty {
            for exp in tomorrowExpenses {
                let concepto = exp.concept.isEmpty ? "N/A" : exp.concept.capitalized
                let importe = exp.amount > 0 ? String(format: "%.2f", exp.amount) : "N/A"
                resumenManana.append("\(concepto) (\(importe)€)")
                totalManana += exp.amount
            }
        }
        
        // Programar notificación para hoy (si hay gastos y es la hora adecuada)
        if !todayExpenses.isEmpty {
            let hour = getNotificationHour()
            let minute = getNotificationMinute()
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            // Solo programar si la hora de notificación es posterior a la hora actual
            if let notificationDate = calendar.date(from: dateComponents),
               notificationDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Gastos pendientes para hoy"
                content.body = "Hoy: " + resumenHoy.joined(separator: ", ") + ". Total: \(String(format: "%.2f", totalHoy))€"
                content.sound = UNNotificationSound.default
                content.badge = 1
                content.categoryIdentifier = NotificationCategory.expenseReminder.rawValue
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let request = UNNotificationRequest(identifier: "summary_expense_today", content: content, trigger: trigger)
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("[RESUMEN] Error al programar notificación resumen de hoy: \(error.localizedDescription)")
                    } else {
                        print("[RESUMEN] Notificación resumen de hoy programada para: \(notificationDate)")
                    }
                    self.updateAppBadgeWithPendingNotifications()
                }
            }
        }
        
        // Programar notificación para mañana (solo gastos de mañana)
        if !tomorrowExpenses.isEmpty {
            let hour = getDayBeforeNotificationHour()
            let minute = getDayBeforeNotificationMinute()
            
            // Calcular la fecha para la notificación del día anterior
            let notificationDate: Date
            if hour > calendar.component(.hour, from: now) || 
               (hour == calendar.component(.hour, from: now) && minute > calendar.component(.minute, from: now)) {
                // Si la hora configurada es posterior a la hora actual, programar para hoy
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.hour = hour
                components.minute = minute
                notificationDate = calendar.date(from: components)!
            } else {
                // Si la hora configurada ya pasó hoy, programar para mañana
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = hour
                components.minute = minute
                notificationDate = calendar.date(from: components)!
            }
            
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            
            let content = UNMutableNotificationContent()
            content.title = "Gastos pendientes para mañana"
            content.body = "Mañana: " + resumenManana.joined(separator: ", ") + ". Total: \(String(format: "%.2f", totalManana))€"
            content.sound = UNNotificationSound.default
            content.badge = 1
            content.categoryIdentifier = NotificationCategory.expenseReminder.rawValue
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "summary_expense_tomorrow", content: content, trigger: trigger)
            notificationCenter.add(request) { error in
                if let error = error {
                    print("[RESUMEN] Error al programar notificación resumen de mañana: \(error.localizedDescription)")
                } else {
                    print("[RESUMEN] Notificación resumen de mañana programada para: \(notificationDate)")
                }
                self.updateAppBadgeWithPendingNotifications()
            }
        }
        
        // Cancelar notificaciones individuales de hoy y mañana
        let idsToCancel = (todayExpenses + tomorrowExpenses).flatMap { exp in
            [NotificationIdentifier.expenseDayBefore.forTransaction(exp.id.uuidString),
             NotificationIdentifier.expenseSameDay.forTransaction(exp.id.uuidString)]
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToCancel)
    }
} 
