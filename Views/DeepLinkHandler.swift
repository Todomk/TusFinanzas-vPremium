import Foundation
import SwiftUI

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    // Estado para determinar si se debe mostrar la vista de añadir GP
    @Published var showAddGPView: Bool = false
    
    // Datos preestablecidos para el formulario de GP
    @Published var prefilledAmount: Double = 0.0
    @Published var prefilledCategory: GPCategory = .otros
    @Published var prefilledPaymentMethod: PaymentMethod = .cash
    
    // Determina si venimos directamente de un botón de cantidad rápida
    @Published var isQuickAmountEntry: Bool = false
    
    // Nuevos estados para control de autoguardado y vista a pantalla completa
    @Published var shouldAutoSave: Bool = false
    @Published var showFullScreenMode: Bool = false
    
    // Estado para controlar la navegación a la pestaña de gastos personales
    @Published var selectedTabIndex: Int = 0
    @Published var navigateToGastosDiarios: Bool = false
    
    // Procesar enlaces profundos desde widgets
    func handleDeepLink(_ url: URL) {
        print("DeepLinkHandler: Procesando URL: \(url)")
        
        // Comprobar si es una URL para añadir GP
        if url.absoluteString.hasPrefix("\(URLSchemeConfig.scheme)://add-gp") {
            // Primero, cerrar cualquier vista existente si está abierta
            if showAddGPView {
                print("DeepLinkHandler: Cerrando vista anterior antes de abrir nueva")
                
                // Resetear también la bandera de navegación a Gastos Diarios para evitar problemas
                navigateToGastosDiarios = false
                
                // Cerrar la vista actual con animación
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAddGPView = false
                }
                
                // Usar un retardo corto para permitir que se cierre la vista anterior
                // antes de abrir la nueva vista
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.processAddGPDeepLink(url)
                }
            } else {
                // No hay vista abierta, procesar directamente
                processAddGPDeepLink(url)
            }
        } else {
            print("DeepLinkHandler: URL no reconocida: \(url)")
        }
    }
    
    // Método separado para procesar el deeplink de añadir GP
    private func processAddGPDeepLink(_ url: URL) {
        // Parsear URL y obtener parámetros
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            // Obtener parámetros de la URL
            let queryItems = components.queryItems ?? []
            
            // Extraer la cantidad
            if let amountItem = queryItems.first(where: { $0.name == "amount" }),
               let amount = Double(amountItem.value ?? "0") {
                prefilledAmount = amount
                print("DeepLinkHandler: Cantidad: \(amount)")
            } else {
                prefilledAmount = 0.0
            }
            
            // Extraer la categoría
            if let categoryItem = queryItems.first(where: { $0.name == "category" }),
               let categoryValue = categoryItem.value,
               let category = GPCategory(rawValue: categoryValue) {
                prefilledCategory = category
                print("DeepLinkHandler: Categoría: \(category.rawValue)")
            } else {
                prefilledCategory = .otros
            }
            
            // Método de pago por defecto es efectivo
            prefilledPaymentMethod = .cash
            print("DeepLinkHandler: Método de pago por defecto: \(prefilledPaymentMethod.rawValue)")
            
            // Extraer el parámetro de autoguardado
            if let autoSaveItem = queryItems.first(where: { $0.name == "autoSave" }),
               autoSaveItem.value == "true" {
                shouldAutoSave = true
                print("DeepLinkHandler: AutoSave: true")
            } else {
                shouldAutoSave = false
                print("DeepLinkHandler: AutoSave: false")
            }
            
            // Determinar si es una entrada rápida (desde botones de cantidad)
            // Si la cantidad es exactamente 0, 5, 10, 15, 20, 25 o 30 euros, considerarla como entrada rápida
            let quickAmounts: [Double] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
            isQuickAmountEntry = quickAmounts.contains(prefilledAmount)
            
            // Si viene de un botón de cantidad rápida y autoSave es true, 
            // activar el modo pantalla completa
            showFullScreenMode = isQuickAmountEntry && shouldAutoSave
            
            print("DeepLinkHandler: Es entrada rápida: \(isQuickAmountEntry)")
            print("DeepLinkHandler: Modo pantalla completa: \(showFullScreenMode)")
            
            // Cambiar a la pestaña "Más" y preparar la navegación
            DispatchQueue.main.async {
                // Seleccionar la pestaña "Más" (índice 3)
                self.selectedTabIndex = 3
                
                // Activar navegación a Gastos Diarios después de un breve retraso
                // para asegurar que primero se cambia la pestaña
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("DeepLinkHandler: Activando navegación a Gastos Diarios")
                    self.navigateToGastosDiarios = true
                    
                    // Activar la bandera para mostrar la vista con animación
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.showAddGPView = true
                    }
                }
            }
            
            print("DeepLinkHandler: Activando vista de añadir GP con valores preestablecidos")
        } else {
            print("DeepLinkHandler: Error al parsear la URL")
        }
    }
} 