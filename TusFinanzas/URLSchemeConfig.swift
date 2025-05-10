import Foundation

// NOTA: Este archivo no reemplaza la configuración en Info.plist, 
// pero proporciona una forma fácil de documentar y referenciar la configuración del esquema URL.
// 
// Debes configurar manualmente el esquema URL en Xcode:
// 1. Selecciona el target de TusFinanzas
// 2. Ve a la pestaña "Info"
// 3. Expande "URL Types"
// 4. Añade un nuevo esquema URL:
//    - Identifier: com.rogalan.TusFinanzas
//    - URL Schemes: tusfinanzas
//    - Role: Editor

struct URLSchemeConfig {
    static let scheme = "tusfinanzas"
    
    // Construir una URL para añadir un gasto personal
    static func buildAddGPURL(amount: Double, category: GPCategory, autoSave: Bool = false) -> URL? {
        guard var components = URLComponents(string: "\(scheme)://add-gp") else {
            return nil
        }
        
        var queryItems = [
            URLQueryItem(name: "amount", value: String(amount)),
            URLQueryItem(name: "category", value: category.rawValue)
        ]
        
        // Añadir parámetro para autoguardado si está activado
        if autoSave {
            queryItems.append(URLQueryItem(name: "autoSave", value: "true"))
        }
        
        components.queryItems = queryItems
        
        return components.url
    }
    
    // Método del parser antiguo - mantenido por compatibilidad
    static func parseAddGPURL(_ url: URL) -> (amount: Double, category: GPCategory)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              url.absoluteString.hasPrefix("\(scheme)://add-gp") else {
            return nil
        }
        
        let queryItems = components.queryItems ?? []
        
        guard let amountItem = queryItems.first(where: { $0.name == "amount" }),
              let amount = Double(amountItem.value ?? "0"),
              let categoryItem = queryItems.first(where: { $0.name == "category" }),
              let categoryValue = categoryItem.value,
              let category = GPCategory(rawValue: categoryValue) else {
            return nil
        }
        
        return (amount, category)
    }
    
    // Versión extendida del parser que también devuelve el parámetro autoSave
    static func parseAddGPURLExtended(_ url: URL) -> (amount: Double, category: GPCategory, autoSave: Bool)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              url.absoluteString.hasPrefix("\(scheme)://add-gp") else {
            return nil
        }
        
        let queryItems = components.queryItems ?? []
        
        guard let amountItem = queryItems.first(where: { $0.name == "amount" }),
              let amount = Double(amountItem.value ?? "0"),
              let categoryItem = queryItems.first(where: { $0.name == "category" }),
              let categoryValue = categoryItem.value else {
            return nil
        }
        
        // Verificar si es una categoría estándar o personalizada
        let category = GPCategory(rawValue: categoryValue) ?? .otros
        
        // Comprobar parámetro autoSave
        let autoSave = queryItems.first(where: { $0.name == "autoSave" })?.value == "true"
        
        return (amount, category, autoSave)
    }
    
    // Versión completa que soporta categorías y métodos de pago personalizados
    static func parseAddGPURLComplete(_ url: URL) -> (amount: Double, category: GPCategory, customCategory: String?, paymentMethod: PaymentMethod, customPaymentMethod: String?, autoSave: Bool)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              url.absoluteString.hasPrefix("\(scheme)://add-gp") else {
            return nil
        }
        
        let queryItems = components.queryItems ?? []
        
        // Verificar que al menos existan los parámetros obligatorios
        guard let amountItem = queryItems.first(where: { $0.name == "amount" }),
              let amount = Double(amountItem.value ?? "0") else {
            return nil
        }
        
        // Procesar categoría (obligatoria)
        var category: GPCategory = .otros
        var customCategory: String? = nil
        
        if let categoryItem = queryItems.first(where: { $0.name == "category" }),
           let categoryValue = categoryItem.value {
            if let standardCategory = GPCategory(rawValue: categoryValue) {
                category = standardCategory
            } else {
                customCategory = categoryValue
            }
        }
        
        // Procesar método de pago (opcional)
        var paymentMethod: PaymentMethod = .cash
        var customPaymentMethod: String? = nil
        
        if let methodItem = queryItems.first(where: { $0.name == "paymentMethod" }),
           let methodValue = methodItem.value {
            if let standardMethod = PaymentMethod(rawValue: methodValue) {
                paymentMethod = standardMethod
            } else {
                paymentMethod = .bank // Usar .bank como respaldo
                customPaymentMethod = methodValue
            }
        }
        
        // Procesar autoSave
        let autoSave = queryItems.first(where: { $0.name == "autoSave" })?.value == "true"
        
        return (amount, category, customCategory, paymentMethod, customPaymentMethod, autoSave)
    }
} 