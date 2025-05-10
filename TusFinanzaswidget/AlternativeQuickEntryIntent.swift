import WidgetKit
import AppIntents

// Esta es una versión simplificada que evita el uso de GPCategory como AppEnum
struct AlternativeQuickEntryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Entrada Rápida"
    static var description: IntentDescription = "Widget para añadir gastos personales rápidamente"

    // Cantidad predefinida para el widget
    @Parameter(title: "Cantidad Predefinida")
    var defaultAmount: Double?
    
    // Categoría predefinida para el widget (como String)
    @Parameter(title: "Categoría Predefinida")
    var defaultCategoryName: String?
    
    // Valores predeterminados
    init() {
        self.defaultAmount = 10.0
        self.defaultCategoryName = "otros"
    }
}

// Extensión para facilitar el uso en el widget
extension AlternativeQuickEntryIntent {
    func getDefaultAmount() -> Double {
        return defaultAmount ?? 10.0
    }
    
    func getDefaultCategory() -> GPCategory {
        guard let categoryName = defaultCategoryName,
              let category = GPCategory(rawValue: categoryName) else {
            return .otros
        }
        return category
    }
} 