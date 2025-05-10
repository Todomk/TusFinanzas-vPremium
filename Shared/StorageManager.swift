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
    private let paymentMethodsKey = "paymentMethods"
    private let categoriesKey = "categories"
    
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
    
    // Métodos para guardar y cargar los métodos de pago
    func savePaymentMethods(_ methods: [String]) {
        print("StorageManager: Guardando métodos de pago")
        print("StorageManager: Número de métodos: \(methods.count)")
        
        if let encoded = try? JSONEncoder().encode(methods) {
            defaults.set(encoded, forKey: paymentMethodsKey)
            print("StorageManager: Métodos de pago guardados correctamente")
        }
    }
    
    func loadPaymentMethods() -> [String] {
        print("StorageManager: Cargando métodos de pago personalizados")
        if let data = defaults.data(forKey: paymentMethodsKey),
           let methods = try? JSONDecoder().decode([String].self, from: data) {
            print("StorageManager: Métodos de pago personalizados cargados correctamente: \(methods.count)")
            return methods
        }
        print("StorageManager: No se encontraron métodos de pago personalizados guardados")
        
        // Devolver un array vacío ya que no hay métodos personalizados guardados
        return []
    }
    
    // Métodos para guardar y cargar las categorías personalizadas
    func saveCategories(_ categories: [String]) {
        print("StorageManager: Guardando categorías personalizadas")
        print("StorageManager: Número de categorías: \(categories.count)")
        
        if let encoded = try? JSONEncoder().encode(categories) {
            defaults.set(encoded, forKey: categoriesKey)
            print("StorageManager: Categorías personalizadas guardadas correctamente")
        }
    }
    
    func loadCategories() -> [String] {
        print("StorageManager: Cargando categorías personalizadas")
        if let data = defaults.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([String].self, from: data) {
            print("StorageManager: Categorías personalizadas cargadas correctamente: \(categories.count)")
            return categories
        }
        print("StorageManager: No se encontraron categorías personalizadas guardadas")
        
        // Devolver un array vacío ya que no hay categorías personalizadas guardadas
        return []
    }
} 
