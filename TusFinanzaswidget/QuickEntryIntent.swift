import AppIntents
import SwiftUI

struct QuickEntryIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Entrada Rápida"
    static var description: IntentDescription = "Widget para añadir gastos personales rápidamente"

    // Cantidad predefinida para el widget
    @Parameter(title: "Cantidad Predefinida", default: 10.0)
    var defaultAmount: Double
    
    // Categoría predefinida para el widget
    @Parameter(title: "Categoría Predefinida", default: .restauracion)
    var defaultCategory: GPCategory
}

// Implementación simplificada para hacer que GPCategory sea compatible con AppIntents
extension GPCategory: AppEnum {
    // Valor estático para typeDisplayRepresentation
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = 
        TypeDisplayRepresentation(name: "Categoría")
    
    // Valor estático para caseDisplayRepresentations - debe ser literal y no calculado
    public static var caseDisplayRepresentations: [GPCategory: DisplayRepresentation] = [
        .restauracion: DisplayRepresentation(title: "Restauración"),
        .gasolina: DisplayRepresentation(title: "Gasolina"),
        .supermercados: DisplayRepresentation(title: "Supermercados"),
        .ropa: DisplayRepresentation(title: "Ropa"),
        .compraOnline: DisplayRepresentation(title: "Compra Online"),
        .salud: DisplayRepresentation(title: "Salud"),
        .belleza: DisplayRepresentation(title: "Belleza"),
        .ocio: DisplayRepresentation(title: "Ocio"),
        .otros: DisplayRepresentation(title: "Otros")
    ]
} 