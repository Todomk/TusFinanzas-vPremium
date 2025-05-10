import WidgetKit
import SwiftUI
import AppIntents

// Dado que URLSchemeConfig no está disponible directamente en el widget,
// creamos una versión simplificada para el widget
struct WidgetURLBuilder {
    static let scheme = "tusfinanzas"
    
    static func buildAddGPURL(amount: Double, category: GPCategory, autoSave: Bool = false) -> URL? {
        guard var components = URLComponents(string: "\(scheme)://add-gp") else {
            return nil
        }
        
        // Añadir impresión de depuración para verificar el importe
        print("Widget URL Builder: Creando URL con importe: \(amount)€")
        
        var queryItems = [
            URLQueryItem(name: "amount", value: String(amount)),
            URLQueryItem(name: "category", value: category.rawValue)
        ]
        
        // Añadir parámetro para autoguardado si está activado
        if autoSave {
            queryItems.append(URLQueryItem(name: "autoSave", value: "true"))
        }
        
        components.queryItems = queryItems
        
        // Debug: imprimir la URL generada
        print("Widget URL Builder: URL generada: \(components.url?.absoluteString ?? "error")")
        
        return components.url
    }
}

struct QuickEntryWidget: Widget {
    let kind: String = "QuickEntryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: AlternativeQuickEntryIntent.self,
            provider: QuickEntryProvider()
        ) { entry in
            QuickEntryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct QuickEntryProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickEntryEntry {
        QuickEntryEntry(
            date: Date(),
            configuration: AlternativeQuickEntryIntent(),
            categories: GPCategory.allCases
        )
    }

    func snapshot(for configuration: AlternativeQuickEntryIntent, in context: Context) async -> QuickEntryEntry {
        QuickEntryEntry(
            date: Date(),
            configuration: configuration,
            categories: GPCategory.allCases
        )
    }
    
    func timeline(for configuration: AlternativeQuickEntryIntent, in context: Context) async -> Timeline<QuickEntryEntry> {
        // Este widget no necesita actualizarse con frecuencia
        let entries = [
            QuickEntryEntry(
                date: Date(),
                configuration: configuration,
                categories: GPCategory.allCases
            )
        ]
        
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct QuickEntryEntry: TimelineEntry {
    let date: Date
    let configuration: AlternativeQuickEntryIntent
    let categories: [GPCategory]
}

struct QuickEntryWidgetEntryView: View {
    var entry: QuickEntryProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallQuickEntryWidget
        case .systemMedium:
            mediumQuickEntryWidget
        default:
            smallQuickEntryWidget
        }
    }
    
    var smallQuickEntryWidget: some View {
        VStack(alignment: .center, spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            
            Text("Añadir Gasto")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.top, 2)
            
            HStack(spacing: 4) {
                Text("0€")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("·")
                    .foregroundColor(.secondary)
                
                Text(displayNameForCategory(entry.configuration.getDefaultCategory()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .cornerRadius(8)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
            
            Text("Toca para añadir")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
        }
        .widgetURL(WidgetURLBuilder.buildAddGPURL(
            amount: 0.0,
            category: .otros,
            autoSave: true
        ))
        .padding(.vertical, 6)
    }
    
    var mediumQuickEntryWidget: some View {
        VStack(alignment: .center, spacing: 0) {
            // Título del widget
            Text("Añadir Gasto")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
                .padding(.bottom, 5)
            
            // Contenido principal
            HStack(spacing: 0) {
                // Columna izquierda con icono - centrado estricto
                ZStack {
                    // Contenedor para centrar perfectamente
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 46, height: 46)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                        }
                        
                        Text("Pulsa un importe")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .widgetURL(WidgetURLBuilder.buildAddGPURL(
                    amount: 0.0,
                    category: .otros,
                    autoSave: true
                ))
                
                Divider()
                    .frame(height: 100)
                
                // Columna derecha - centrado estricto
                ZStack {
                    // Organización manual de los botones para mejor centrado
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            quickButtonWithFixed(amount: 5)
                            quickButtonWithFixed(amount: 10)
                            quickButtonWithFixed(amount: 15)
                        }
                        
                        HStack(spacing: 12) {
                            quickButtonWithFixed(amount: 20)
                            quickButtonWithFixed(amount: 25)
                            quickButtonWithFixed(amount: 30)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
    }
    
    // Botón de importe simplificado para centrado perfecto
    func quickButtonWithFixed(amount: Double) -> some View {
        let category: GPCategory = .otros
        
        return Link(destination: WidgetURLBuilder.buildAddGPURL(amount: amount, category: category, autoSave: true) ?? URL(string: "tusfinanzas://")!) {
            Text("\(Int(amount))€")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 38, height: 26)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            greenGradientForAmount(amount),
                            greenGradientForAmount(amount).opacity(0.85)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
    
    // Función para obtener un tono de verde según el importe
    func greenGradientForAmount(_ amount: Double) -> Color {
        switch amount {
        case 5:
            return Color(red: 0.4, green: 0.8, blue: 0.4)  // Verde muy claro/pastel para 5€
        case 10:
            return Color(red: 0.3, green: 0.7, blue: 0.3)  // Verde claro para 10€
        case 15:
            return Color(red: 0.2, green: 0.6, blue: 0.2)  // Verde medio-claro para 15€
        case 20:
            return Color(red: 0.1, green: 0.5, blue: 0.1)  // Verde medio para 20€
        case 25:
            return Color(red: 0.05, green: 0.4, blue: 0.05) // Verde oscuro para 25€
        case 30:
            return Color(red: 0.0, green: 0.35, blue: 0.0)  // Verde muy oscuro para 30€
        default:
            return Color.green
        }
    }
    
    // Función para obtener el color asociado a cada categoría
    func colorForCategory(_ category: GPCategory) -> Color {
        switch category {
        case .restauracion:
            return Color.orange
        case .gasolina:
            return Color.red
        case .supermercados:
            return Color.green
        case .ropa:
            return Color.purple
        case .compraOnline:
            return Color.blue
        case .salud:
            return Color.pink
        case .belleza:
            return Color.teal
        case .ocio:
            return Color.indigo
        case .otros:
            return Color.gray
        }
    }
    
    func displayNameForCategory(_ category: GPCategory) -> String {
        switch category {
        case .restauracion: return "Restauración"
        case .gasolina: return "Gasolina"
        case .supermercados: return "Supermercados"
        case .ropa: return "Ropa"
        case .compraOnline: return "Compra Online"
        case .salud: return "Salud"
        case .belleza: return "Belleza"
        case .ocio: return "Ocio"
        case .otros: return "Otros"
        }
    }
    
    func iconForCategory(_ category: GPCategory) -> String {
        switch category {
        case .restauracion:
            return "fork.knife"
        case .gasolina:
            return "fuelpump.fill"
        case .supermercados:
            return "cart.fill"
        case .ropa:
            return "tshirt.fill"
        case .compraOnline:
            return "bag.fill"
        case .salud:
            return "heart.fill"
        case .belleza:
            return "scissors"
        case .ocio:
            return "gamecontroller.fill"
        case .otros:
            return "ellipsis.circle.fill"
        }
    }
}

#Preview(as: .systemSmall) {
    QuickEntryWidget()
} timeline: {
    QuickEntryEntry(
        date: .now,
        configuration: AlternativeQuickEntryIntent(),
        categories: GPCategory.allCases
    )
}

#Preview(as: .systemMedium) {
    QuickEntryWidget()
} timeline: {
    QuickEntryEntry(
        date: .now,
        configuration: AlternativeQuickEntryIntent(),
        categories: GPCategory.allCases
    )
} 