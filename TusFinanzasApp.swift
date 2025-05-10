import SwiftUI

@main
struct TusFinanzasApp: App {
    @StateObject private var viewModel = FinanceViewModel()
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var selectedTab = 0
    @State private var navigateToGastosDiarios = false
    
    init() {
        // Ejecutar la prueba de cálculo al iniciar la aplicación
        Transaction.testNextAppearanceCalculation()
        
        // Registrar el esquema de URL personalizado
        print("TusFinanzasApp: Registrando esquema de URL tusfinanzas://")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Vista principal de la app - Usar la vista ContentView completa
                ContentView(selectedTab: $selectedTab, navigateToGastosDiarios: $navigateToGastosDiarios)
                    .environmentObject(viewModel)
                    .environmentObject(deepLinkHandler)
                    .onAppear {
                        print("TusFinanzasApp: Aplicación iniciada")
                    }
                
                // Fondo negro completo cuando se muestra una vista modal
                if deepLinkHandler.showAddGPView {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(1)
                        .zIndex(1)
                
                    // Superposición oscura semitransparente solo para modo no pantalla completa
                    if !deepLinkHandler.showFullScreenMode {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .ignoresSafeArea()
                            .opacity(1)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    deepLinkHandler.showAddGPView = false
                                }
                            }
                            .zIndex(2)
                    }
                    
                    // Si está en modo pantalla completa, usar AddGPTransactionView
                    if deepLinkHandler.showFullScreenMode {
                        AddGPTransactionView()
                            .environmentObject(viewModel)
                            .environmentObject(deepLinkHandler)
                            .scaleEffect(1.0)
                            .opacity(1)
                            .zIndex(3)
                    } else {
                        // Vista modal para añadir gasto personal
                        QuickGPEntryView(
                            isPresented: $deepLinkHandler.showAddGPView,
                            initialAmount: deepLinkHandler.prefilledAmount,
                            initialCategory: deepLinkHandler.prefilledCategory,
                            initialPaymentMethod: deepLinkHandler.prefilledPaymentMethod,
                            isQuickAmountEntry: deepLinkHandler.isQuickAmountEntry,
                            viewModel: viewModel
                        )
                        .scaleEffect(1.0)
                        .opacity(1)
                        .zIndex(3)
                    }
                }
            }
            .onOpenURL { url in
                // Manejar URL entrantes (desde widgets)
                print("TusFinanzasApp: URL recibida: \(url)")
                
                // Al recibir una URL, procesarla (que incluirá lógica para cerrar vistas previas)
                deepLinkHandler.handleDeepLink(url)
                
                // Las animaciones ahora se manejan internamente en handleDeepLink
                // ya que necesitamos diferenciar entre abrir una nueva vista
                // y cerrar una existente para abrir una nueva
            }
        }
    }
} 
