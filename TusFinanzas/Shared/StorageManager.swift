import Foundation
import WidgetKit

class StorageManager {
    static let shared = StorageManager()
    
    // Usar App Group para compartir datos con el widget
    private let appGroupID = "group.com.rogalan.TusFinanzas"
    private let defaults: UserDefaults
    
    private let incomesKey = "incomes"
    private let expensesKey = "expenses"
    private let subscriptionsKey = "subscriptions"
    private let gpTransactionsKey = "gpTransactions"
    private let tipsKey = "tips"
    private let categoriesKey = "customCategories"
    private let paymentMethodsKey = "customPaymentMethods"
    private let paymentMethodsOrderKey = "paymentMethodsOrder"
    private let categoriesOrderKey = "categoriesOrder"
    
    private init() {
        // Usar UserDefaults con el App Group
        if let groupDefaults = UserDefaults(suiteName: appGroupID) {
            self.defaults = groupDefaults
            print("StorageManager: Usando App Group UserDefaults")
        } else {
            self.defaults = UserDefaults.standard
            print("StorageManager: No se pudo acceder al App Group, usando UserDefaults estándar")
        }
    }
    
    func saveTransactions(_ transactions: [Transaction], forKey key: String) {
        print("StorageManager: Guardando transacciones para key: \(key)")
        print("StorageManager: Número de transacciones: \(transactions.count)")
        
        // Verificar si las transacciones son diferentes a las guardadas
        if let savedData = defaults.data(forKey: key),
           let savedTransactions = try? JSONDecoder().decode([Transaction].self, from: savedData),
           savedTransactions == transactions {
            print("StorageManager: Las transacciones son idénticas a las guardadas, omitiendo guardado")
            return
        }
        
        if let encoded = try? JSONEncoder().encode(transactions) {
            defaults.set(encoded, forKey: key)
            print("StorageManager: Transacciones guardadas correctamente")
            
            // Recargar el widget cuando los datos cambian
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func loadTransactions(for key: String) -> [Transaction] {
        print("StorageManager: Cargando transacciones para key: \(key)")
        if let data = defaults.data(forKey: key),
           let transactions = try? JSONDecoder().decode([Transaction].self, from: data) {
            print("StorageManager: Transacciones cargadas correctamente: \(transactions.count)")
            return transactions
        }
        print("StorageManager: No se encontraron transacciones para key: \(key)")
        return []
    }
    
    func saveIncomes(_ incomes: [Transaction]) {
        saveTransactions(incomes, forKey: incomesKey)
    }
    
    func saveExpenses(_ expenses: [Transaction]) {
        saveTransactions(expenses, forKey: expensesKey)
    }
    
    func saveSubscriptions(_ subscriptions: [Transaction]) {
        saveTransactions(subscriptions, forKey: subscriptionsKey)
    }
    
    func saveGPTransactions(_ transactions: [Transaction]) {
        saveTransactions(transactions, forKey: gpTransactionsKey)
    }
    
    func loadIncomes() -> [Transaction] {
        return loadTransactions(for: incomesKey)
    }
    
    func loadExpenses() -> [Transaction] {
        return loadTransactions(for: expensesKey)
    }
    
    func loadSubscriptions() -> [Transaction] {
        return loadTransactions(for: subscriptionsKey)
    }
    
    func loadGPTransactions() -> [Transaction] {
        return loadTransactions(for: gpTransactionsKey)
    }
    
    func saveTips(_ tips: [Transaction]) {
        if let encoded = try? JSONEncoder().encode(tips) {
            defaults.set(encoded, forKey: tipsKey)
            // Recargar el widget cuando los datos cambian
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func loadTips() -> [Transaction] {
        if let data = defaults.data(forKey: tipsKey),
           let decoded = try? JSONDecoder().decode([Transaction].self, from: data) {
            return decoded
        }
        return []
    }
    
    // MARK: - Métodos para Categorías Personalizadas
    
    func saveCategories(_ categories: [String]) {
        print("StorageManager: Guardando \(categories.count) categorías personalizadas")
        defaults.set(categories, forKey: categoriesKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func loadCategories() -> [String] {
        print("StorageManager: Cargando categorías personalizadas")
        if let categories = defaults.array(forKey: categoriesKey) as? [String] {
            print("StorageManager: Se cargaron \(categories.count) categorías personalizadas")
            return categories
        }
        print("StorageManager: No se encontraron categorías personalizadas")
        return []
    }
    
    // MARK: - Métodos para guardar el orden completo de las categorías
    
    func saveCategoriesOrder(_ categories: [String]) {
        print("StorageManager: Guardando orden completo de \(categories.count) categorías")
        print("StorageManager: Orden completo guardado:")
        for (index, category) in categories.enumerated() {
            print("  \(index + 1). \(category)")
        }
        
        defaults.set(categories, forKey: categoriesOrderKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func loadCategoriesOrder() -> [String] {
        print("StorageManager: Cargando orden completo de categorías")
        if let categories = defaults.array(forKey: categoriesOrderKey) as? [String] {
            print("StorageManager: Se cargó el orden de \(categories.count) categorías")
            print("StorageManager: Orden completo cargado:")
            for (index, category) in categories.enumerated() {
                print("  \(index + 1). \(category)")
            }
            return categories
        }
        print("StorageManager: No se encontró un orden guardado de categorías")
        return []
    }
    
    // MARK: - Métodos para Métodos de Pago Personalizados
    
    func savePaymentMethods(_ methods: [String]) {
        print("StorageManager: Guardando \(methods.count) métodos de pago personalizados")
        print("StorageManager: Orden guardado:")
        for (index, method) in methods.enumerated() {
            print("  \(index + 1). \(method)")
        }
        
        defaults.set(methods, forKey: paymentMethodsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func loadPaymentMethods() -> [String] {
        print("StorageManager: Cargando métodos de pago personalizados")
        if let methods = defaults.array(forKey: paymentMethodsKey) as? [String] {
            print("StorageManager: Se cargaron \(methods.count) métodos de pago personalizados")
            print("StorageManager: Orden cargado:")
            for (index, method) in methods.enumerated() {
                print("  \(index + 1). \(method)")
            }
            return methods
        }
        print("StorageManager: No se encontraron métodos de pago personalizados")
        return []
    }
    
    // MARK: - Métodos para guardar el orden completo de los métodos de pago
    
    func saveMethodsOrder(_ methods: [String]) {
        print("StorageManager: Guardando orden completo de \(methods.count) métodos de pago")
        print("StorageManager: Orden completo guardado:")
        for (index, method) in methods.enumerated() {
            print("  \(index + 1). \(method)")
        }
        
        defaults.set(methods, forKey: paymentMethodsOrderKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func loadMethodsOrder() -> [String] {
        print("StorageManager: Cargando orden completo de métodos de pago")
        if let methods = defaults.array(forKey: paymentMethodsOrderKey) as? [String] {
            print("StorageManager: Se cargó el orden de \(methods.count) métodos de pago")
            print("StorageManager: Orden completo cargado:")
            for (index, method) in methods.enumerated() {
                print("  \(index + 1). \(method)")
            }
            return methods
        }
        print("StorageManager: No se encontró un orden guardado de métodos de pago")
        return []
    }
    
    // MARK: - Limpieza de archivos backup
    
    func cleanBackupFiles() -> (success: Bool, message: String, filesDeleted: Int) {
        print("StorageManager: Iniciando limpieza de archivos backup")
        
        let fileManager = FileManager.default
        var filesDeleted = 0
        var errors: [String] = []
        
        // Obtener el directorio de documentos de la app
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, 
                                                       in: .userDomainMask).first else {
            return (false, "No se pudo acceder al directorio de documentos", 0)
        }
        
        // Obtener el directorio principal de la app (Bundle)
        let bundleDirectory = Bundle.main.bundleURL
        
        // Patrones de archivos backup a buscar
        let backupPatterns = [
            "*.bak",
            "*.backup",
            "*.backup-*",
            "*.v1.*.bak",
            "*2.bak",
            "*.orig",
            "*.tmp"
        ]
        
        // Directorios donde buscar archivos backup
        let searchDirectories = [
            documentsDirectory,
            bundleDirectory
        ]
        
        // Función para verificar si un archivo coincide con algún patrón
        func matchesBackupPattern(_ filename: String) -> Bool {
            return backupPatterns.contains { pattern in
                let regexPattern = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")
                
                return filename.range(of: "^\(regexPattern)$", options: .regularExpression) != nil
            }
        }
        
        // Buscar y eliminar archivos backup en cada directorio
        for directory in searchDirectories {
            do {
                // Buscar archivos de forma recursiva
                let directoryContents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                
                for fileURL in directoryContents {
                    let filename = fileURL.lastPathComponent
                    
                    // Verificar si el archivo coincide con algún patrón de backup
                    if matchesBackupPattern(filename) {
                        // Verificar que es un archivo regular (no directorio)
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                        if resourceValues.isRegularFile == true {
                            do {
                                try fileManager.removeItem(at: fileURL)
                                filesDeleted += 1
                                print("StorageManager: Archivo eliminado: \(filename)")
                            } catch {
                                let errorMsg = "Error al eliminar \(filename): \(error.localizedDescription)"
                                errors.append(errorMsg)
                                print("StorageManager: \(errorMsg)")
                            }
                        }
                    }
                }
            } catch {
                let errorMsg = "Error al acceder al directorio \(directory.path): \(error.localizedDescription)"
                errors.append(errorMsg)
                print("StorageManager: \(errorMsg)")
            }
        }
        
        // Generar mensaje de resultado
        var message: String
        if filesDeleted > 0 {
            message = "Se eliminaron \(filesDeleted) archivo(s) backup correctamente"
            if !errors.isEmpty {
                message += "\n\nAlgunas operaciones fallaron:\n" + errors.joined(separator: "\n")
            }
        } else if errors.isEmpty {
            message = "No se encontraron archivos backup para eliminar"
        } else {
            message = "No se pudieron eliminar archivos backup:\n" + errors.joined(separator: "\n")
        }
        
        print("StorageManager: Limpieza completada. Archivos eliminados: \(filesDeleted)")
        return (filesDeleted > 0 || errors.isEmpty, message, filesDeleted)
    }
} 
