import Foundation
import WidgetKit

// Estructura para los datos que se mostrarán en el widget
struct WidgetData: Codable {
    let totalIngresos: Double
    let totalGastos: Double
    let totalSuscripciones: Double
    let totalGP: Double
    let totalPropinas: Double
    let beneficio: Double
    let fechaActualizacion: Date
    
    // Método de conveniencia para crear datos vacíos
    static func empty() -> WidgetData {
        return WidgetData(
            totalIngresos: 0,
            totalGastos: 0,
            totalSuscripciones: 0,
            totalGP: 0,
            totalPropinas: 0,
            beneficio: 0,
            fechaActualizacion: Date()
        )
    }
}

class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let appGroupID = "group.com.rogalan.TusFinanzas"
    private let widgetDataKey = "widgetData"
    
    private init() {}
    
    // Obtener datos para el widget
    func getWidgetData() -> WidgetData {
        print("WidgetDataProvider: Obteniendo datos para widget")

        // Intentar leer desde UserDefaults primero (los datos más recientes)
        if let savedData = getSavedWidgetData() {
            print("WidgetDataProvider: Usando datos guardados")
            print("- Ingresos: \(savedData.totalIngresos)")
            print("- Gastos: \(savedData.totalGastos)")
            print("- Beneficio: \(savedData.beneficio)")
            return savedData
        }
        
        print("WidgetDataProvider: No hay datos guardados, calculando nuevos datos")
        
        // Si no hay datos guardados, calcularlos desde las transacciones
        let calculatedData = calculateWidgetDataFromTransactions()
        print("WidgetDataProvider: Datos calculados")
        print("- Ingresos: \(calculatedData.totalIngresos)")
        print("- Gastos: \(calculatedData.totalGastos)")
        print("- Beneficio: \(calculatedData.beneficio)")
        
        return calculatedData
    }
    
    // Leer datos guardados del widget
    private func getSavedWidgetData() -> WidgetData? {
        guard let groupDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WidgetDataProvider: No se pudo acceder al App Group")
            return nil
        }
        
        guard let data = groupDefaults.data(forKey: widgetDataKey) else {
            print("WidgetDataProvider: No hay datos guardados con la clave \(widgetDataKey)")
            return nil
        }
        
        do {
            let decodedData = try JSONDecoder().decode(WidgetData.self, from: data)
            print("WidgetDataProvider: Datos decodificados correctamente")
            return decodedData
        } catch {
            print("WidgetDataProvider: Error al decodificar los datos: \(error)")
            return nil
        }
    }
    
    // Calcular datos del widget desde las transacciones
    private func calculateWidgetDataFromTransactions() -> WidgetData {
        // Cargar transacciones desde StorageManager
        let incomes = StorageManager.shared.loadIncomes()
        let expenses = StorageManager.shared.loadExpenses()
        let subscriptions = StorageManager.shared.loadSubscriptions()
        let gpTransactions = StorageManager.shared.loadGPTransactions()
        let tips = StorageManager.shared.loadTips()
        
        // Verificar si se deben mostrar propinas
        let showTips = UserDefaults.standard.bool(forKey: "showTips")
        
        // Calcular totales
        let now = Date()
        
        // Ingresos (excluir transacciones futuras)
        let totalIngresos = incomes
            .filter { !($0.startDate != nil && $0.startDate! > now) }
            .reduce(0) { $0 + $1.amount }
        
        // Gastos (excluir Gastos Diarios y transacciones futuras)
        let totalGastos = expenses
            .filter { $0.concept != "Gastos Diarios" && !($0.startDate != nil && $0.startDate! > now) }
            .reduce(0) { $0 + $1.amount }
        
        // Gastos de otras cuentas (excluir transacciones futuras)
        let totalSuscripciones = subscriptions
            .filter { !($0.startDate != nil && $0.startDate! > now) }
            .reduce(0) { $0 + $1.amount }
        
        // GP (excluir transacciones futuras)
        let totalGP = gpTransactions
            .filter { !($0.startDate != nil && $0.startDate! > now) }
            .reduce(0) { $0 + $1.amount }
        
        // Propinas (calcular total del mes actual) - solo si showTips es true
        let totalPropinas = showTips ? calculateTipsTotal(tips: tips) : 0
        
        // Calcular beneficio según la previsión
        // Total de ingresos con/sin propinas - (todos los gastos: gastos normales + gastos de otras cuentas + gastos personales)
        let totalIngresosAjustado = totalIngresos + (showTips ? totalPropinas : 0)
        let totalGastosCombinados = totalGastos + totalSuscripciones + totalGP
        let beneficio = totalIngresosAjustado - totalGastosCombinados
        
        print("WidgetDataProvider: Cálculo directo de beneficio:")
        print("- Total Ingresos: \(totalIngresosAjustado) (Ingresos base: \(totalIngresos) + Propinas: \(showTips ? totalPropinas : 0))")
        print("- Mostrar propinas: \(showTips ? "SÍ" : "NO")")
        print("- Total Gastos Combinados: \(totalGastosCombinados) = Gastos(\(totalGastos)) + Gastos de otras cuentas(\(totalSuscripciones)) + GP(\(totalGP))")
        print("- Beneficio calculado: \(beneficio)")
        
        // Crear y guardar objeto WidgetData
        let widgetData = WidgetData(
            totalIngresos: totalIngresosAjustado,
            totalGastos: totalGastosCombinados, // Usar el total combinado de gastos
            totalSuscripciones: totalSuscripciones,
            totalGP: totalGP,
            totalPropinas: totalPropinas,
            beneficio: beneficio,
            fechaActualizacion: Date()
        )
        
        saveWidgetData(widgetData)
        return widgetData
    }
    
    // Calcular total de propinas del mes actual
    private func calculateTipsTotal(tips: [Transaction]) -> Double {
        guard let tipTransaction = tips.first else {
            return 0
        }
        
        guard let weeklyAmounts = tipTransaction.weeklyAmounts else {
            return 0
        }
        
        // Sumar todas las cantidades
        return weeklyAmounts.values.reduce(0, +)
    }
    
    // Guardar datos del widget
    func saveWidgetData(_ data: WidgetData) {
        print("WidgetDataProvider: Guardando datos del widget")
        print("- Ingresos: \(data.totalIngresos)")
        print("- Gastos: \(data.totalGastos)")
        print("- Beneficio: \(data.beneficio)")
        
        guard let groupDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WidgetDataProvider: ERROR - No se pudo acceder al App Group para guardar")
            return
        }
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            print("WidgetDataProvider: Datos codificados correctamente (\(encodedData.count) bytes)")
            
            groupDefaults.set(encodedData, forKey: widgetDataKey)
            groupDefaults.synchronize() // Forzar sincronización
            
            print("WidgetDataProvider: Datos guardados correctamente")
        } catch {
            print("WidgetDataProvider: ERROR al codificar los datos: \(error)")
        }
    }
    
    // Actualizar datos del widget y recargar timeline
    func updateWidgetData() {
        print("WidgetDataProvider: Actualizando datos del widget y recargando timeline")
        
        let widgetData = calculateWidgetDataFromTransactions()
        saveWidgetData(widgetData)
        
        print("WidgetDataProvider: Solicitando recarga del widget")
        // Notificar a WidgetKit para que actualice el widget
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetDataProvider: Timeline del widget recargada")
    }
} 