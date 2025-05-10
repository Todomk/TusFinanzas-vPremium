//
//  TusFinanzaswidget.swift
//  TusFinanzaswidget
//
//  Created by Angel Luis Rodriguez Malagon on 3/5/25.
//

import WidgetKit
import SwiftUI

// Acceder directamente a los archivos compartidos
// No es necesario importarlos específicamente porque están en el mismo target

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(), 
            configuration: ConfigurationAppIntent(),
            widgetData: WidgetData.empty()
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // Obtener datos reales para la instantánea
        let widgetData = WidgetDataProvider.shared.getWidgetData()
        
        // Depuración: Imprimir datos
        print("Widget Snapshot - Datos obtenidos:")
        print("Ingresos: \(widgetData.totalIngresos)")
        print("Gastos: \(widgetData.totalGastos)")
        print("Beneficio: \(widgetData.beneficio)")
        print("Fecha actualización: \(widgetData.fechaActualizacion)")
        
        return SimpleEntry(
            date: Date(), 
            configuration: configuration,
            widgetData: widgetData
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // Obtener datos reales
        let widgetData = WidgetDataProvider.shared.getWidgetData()
        
        // Depuración: Imprimir datos y verificar App Group
        print("Widget Timeline - Datos obtenidos:")
        print("Ingresos: \(widgetData.totalIngresos)")
        print("Gastos: \(widgetData.totalGastos)")
        print("Beneficio: \(widgetData.beneficio)")
        
        // Verificar si podemos acceder a los datos del App Group
        let appGroupID = "group.com.rogalan.TusFinanzas"
        if let groupDefaults = UserDefaults(suiteName: appGroupID) {
            print("Widget puede acceder al App Group: SÍ")
            if let data = groupDefaults.data(forKey: "widgetData") {
                print("Widget encontró datos en widgetData: SÍ (\(data.count) bytes)")
            } else {
                print("Widget encontró datos en widgetData: NO")
            }
        } else {
            print("Widget puede acceder al App Group: NO")
        }
        
        // Intentar cargar transacciones directamente
        let storageManager = StorageManager.shared
        let ingresos = storageManager.loadIncomes()
        let gastos = storageManager.loadExpenses()
        let suscripciones = storageManager.loadSubscriptions()
        
        print("Transacciones cargadas directamente:")
        print("- Ingresos: \(ingresos.count)")
        print("- Gastos: \(gastos.count)")
        
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        // Crear una entrada para ahora
        let entry = SimpleEntry(
            date: currentDate,
            configuration: configuration,
            widgetData: widgetData
        )
        entries.append(entry)
        
        // Programar la próxima actualización para dentro de una hora
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        
        return Timeline(entries: entries, policy: .after(nextUpdateDate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let widgetData: WidgetData
}

struct TusFinanzaswidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }
    
    // Widget tamaño pequeño - Mostrar beneficio principal
    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Beneficio")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 4)
                .padding(.leading, 2)
            
            Text(formatCurrency(entry.widgetData.beneficio))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(entry.widgetData.beneficio >= 0 ? .green : .red)
                .shadow(color: Color.black.opacity(0.08), radius: 0.5, x: 0, y: 0.5)
                .padding(.leading, 2)
            
            Spacer(minLength: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ingresos: \(formatCurrency(entry.widgetData.totalIngresos))")
                    .font(.caption)
                    .padding(.bottom, 1)
                    .foregroundColor(.blue.opacity(0.9))
                
                Text("Gastos: \(formatCurrency(entry.widgetData.totalGastos))")
                    .font(.caption)
                    .padding(.bottom, 1)
                    .foregroundColor(.red.opacity(0.9))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .padding(.horizontal, 2)
                
            Text(formatDate(entry.widgetData.fechaActualizacion))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 3)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // Widget tamaño mediano - Mostrar más información
    var mediumWidget: some View {
        HStack(alignment: .top, spacing: 0) {
            // Columna izquierda: Beneficio
            VStack(alignment: .leading, spacing: 4) {
                Text("Beneficio")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.leading, 2)
                
                Text(formatCurrency(entry.widgetData.beneficio))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(entry.widgetData.beneficio >= 0 ? .green : .red)
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, x: 0, y: 0.5)
                    .padding(.leading, 2)
                
// CÓDIGO ELIMINADO: Ya no se muestra "Previsión" en el widget
                // Text("Previsión")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
                
                Spacer()
                
                Text(formatDate(entry.widgetData.fechaActualizacion))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 16)
            
            Divider()
                .padding(.vertical, 8)
            
            // Columna derecha: Desglose
            VStack(alignment: .leading, spacing: 5) {
                dataRow(label: "Ingresos:", value: formatCurrency(entry.widgetData.totalIngresos), color: .blue)
                dataRow(label: "Gastos:", value: formatCurrency(entry.widgetData.totalGastos - entry.widgetData.totalGP), color: .red)
                dataRow(label: "Gastos P:", value: formatCurrency(entry.widgetData.totalGP), color: .purple)
                dataRow(label: "Propinas:", value: formatCurrency(entry.widgetData.totalPropinas), color: .green)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }
    
    // Widget tamaño grande - Mostrar toda la información
    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cabecera con beneficio
            Text("Resumen Financiero")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 6)
                .padding(.leading, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Text("Beneficio:")
                    .fontWeight(.medium)
                
                Text(formatCurrency(entry.widgetData.beneficio))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(entry.widgetData.beneficio >= 0 ? .green : .red)
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, x: 0, y: 0.5)
            }
            .padding(.bottom, 3)
            .padding(.leading, 2)
            
            Divider()
                .padding(.vertical, 3)
            
            // Secciones detalladas
            VStack(alignment: .leading, spacing: 8) {
                detailSection(
                    title: "Ingresos",
                    value: formatCurrency(entry.widgetData.totalIngresos),
                    color: .blue,
                    systemImage: "arrow.down.circle.fill"
                )
                
                detailSection(
                    title: "Gastos",
                    value: formatCurrency(entry.widgetData.totalGastos - entry.widgetData.totalGP),
                    color: .red,
                    systemImage: "arrow.up.circle.fill"
                )
                
                detailSection(
                    title: "Gastos Personales",
                    value: formatCurrency(entry.widgetData.totalGP),
                    color: .purple,
                    systemImage: "person.circle.fill"
                )
                
                detailSection(
                    title: "Propinas",
                    value: formatCurrency(entry.widgetData.totalPropinas),
                    color: .green,
                    systemImage: "hand.thumbsup.fill"
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            Spacer()
            
            Text(formatDate(entry.widgetData.fechaActualizacion))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 3)
                .padding(.leading, 2)
        }
        .padding(.horizontal, 16)
    }
    
    // Componentes auxiliares
    private func dataRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .padding(.leading, 2)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
    
    private func detailSection(title: String, value: String, color: Color, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 1, x: 0, y: 1)
                .padding(.leading, 2)
            
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    // Funciones de formato
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: amount)) ?? "€0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        
        return "Actualizado: \(formatter.string(from: date))"
    }
}

struct TusFinanzaswidget: Widget {
    let kind: String = "TusFinanzaswidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TusFinanzaswidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    TusFinanzaswidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), widgetData: WidgetData.empty())
}

#Preview(as: .systemMedium) {
    TusFinanzaswidget()
} timeline: {
    let previewData = WidgetData(
        totalIngresos: 2500.0,
        totalGastos: 1200.0,
        totalSuscripciones: 0.0,
        totalGP: 350.0,
        totalPropinas: 120.0,
        beneficio: 800.0,
        fechaActualizacion: Date()
    )
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), widgetData: previewData)
}

#Preview(as: .systemLarge) {
    TusFinanzaswidget()
} timeline: {
    let previewData = WidgetData(
        totalIngresos: 2500.0,
        totalGastos: 1200.0,
        totalSuscripciones: 0.0,
        totalGP: 350.0,
        totalPropinas: 120.0,
        beneficio: 800.0,
        fechaActualizacion: Date()
    )
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), widgetData: previewData)
}
