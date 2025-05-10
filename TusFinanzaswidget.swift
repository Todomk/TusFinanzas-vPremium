//
// AVISO: ESTE ES UN ARCHIVO ANTIGUO Y DUPLICADO. NO MODIFICAR.
// El widget actual se encuentra en /TusFinanzaswidget/TusFinanzaswidget.swift
//
//
//  TusFinanzaswidget.swift
//  TusFinanzaswidget
//
//  Created by Angel Luis Rodriguez Malagon on 3/5/25.
//

import WidgetKit
import SwiftUI
import Intents

// Acceder directamente a los archivos compartidos
// No es necesario importarlos específicamente porque están en el mismo target

// Estructura para la configuración del widget usando Intents tradicional
struct SimpleConfigurationIntent: Equatable {
    // Simplificado para evitar problemas de compatibilidad
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(), 
            configuration: SimpleConfigurationIntent(),
            widgetData: WidgetData.empty()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // Simplificar para evitar errores
        let widgetData = WidgetDataProvider.shared.getWidgetData()
        let entry = SimpleEntry(
            date: Date(), 
            configuration: SimpleConfigurationIntent(),
            widgetData: widgetData
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        // Simplificar para evitar errores
        let widgetData = WidgetDataProvider.shared.getWidgetData()
        
        let entry = SimpleEntry(
            date: Date(),
            configuration: SimpleConfigurationIntent(),
            widgetData: widgetData
        )
        
        // Programar la próxima actualización para dentro de una hora
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: SimpleConfigurationIntent
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
            Text("Beneficio (Previsión)")
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
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Gastos (TOTAL+PENDIENTES): \(formatCurrency(entry.widgetData.totalGastos))")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.9))
                }
                .padding(.bottom, 1)
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
                Text("Beneficio (Previsión)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.leading, 2)
                
                Text(formatCurrency(entry.widgetData.beneficio))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(entry.widgetData.beneficio >= 0 ? .green : .red)
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, x: 0, y: 0.5)
                    .padding(.leading, 2)
                
                Text("(con todo pagado)")
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
                dataRow(label: "Gastos (TOTAL+PENDIENTES):", value: formatCurrency(entry.widgetData.totalGastos), color: .red)
                dataRow(label: "- De los cuales GP:", value: formatCurrency(entry.widgetData.totalGP), color: .purple)
                dataRow(label: "Propinas:", value: formatCurrency(entry.widgetData.totalPropinas), color: .green)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
    }
    
    // Widget tamaño grande - Mostrar toda la información
    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cabecera con beneficio - SIMPLIFICADO
            Text("Resumen Financiero")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 6)
                .padding(.leading, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            HStack {
                Text("Beneficio (Previsión con todo pagado):")
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
                    title: "Gastos (TOTAL+PENDIENTES)",
                    value: formatCurrency(entry.widgetData.totalGastos),
                    color: .red,
                    systemImage: "arrow.up.circle.fill"
                )
                
                detailSection(
                    title: "- De los cuales GP",
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TusFinanzaswidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview {
    TusFinanzaswidgetEntryView(entry: SimpleEntry(
        date: .now,
        configuration: SimpleConfigurationIntent(),
        widgetData: WidgetData(
            totalIngresos: 2500.0,
            totalGastos: 1200.0,
            totalGP: 350.0,
            totalPropinas: 120.0,
            beneficio: 800.0,
            fechaActualizacion: Date()
        )
    ))
    .previewContext(WidgetPreviewContext(family: .systemMedium))
}
