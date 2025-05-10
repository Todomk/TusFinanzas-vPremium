import SwiftUI
import UserNotifications

@main
struct TusFinanzasApp: App {
    @StateObject private var viewModel = FinanceViewModel()
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @State private var selectedTab = 0
    @State private var navigateToGastosDiarios = false
    
    init() {
        // Ejecutar la prueba de cálculo al iniciar la aplicación
        Transaction.testNextAppearanceCalculation()
        
        // Configurar las notificaciones
        configureNotifications()
        
        // Registrar el esquema de URL personalizado
        print("TusFinanzasApp: Registrando esquema de URL tusfinanzas://")
        
        // Asignar el delegate de notificaciones
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Actualizar el badge al iniciar la app
        NotificationManager.shared.updateAppBadgeWithPendingNotifications()
    }
    
    // Método para configurar las notificaciones
    private func configureNotifications() {
        // Verificar si las notificaciones están habilitadas
        let notificationsEnabled = UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled")
        print("TusFinanzasApp: Notificaciones de gastos \(notificationsEnabled ? "habilitadas" : "deshabilitadas")")
        
        if notificationsEnabled {
            // Configurar categorías de notificación
            let notificationCenter = UNUserNotificationCenter.current()
            
            // Solicitar permiso si están habilitadas
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    print("TusFinanzasApp: Permisos de notificación concedidos, programando notificaciones")
                    // Programar notificaciones para gastos pendientes
                    DispatchQueue.main.async {
                        self.viewModel.scheduleExpenseNotifications()
                    }
                } else {
                    print("TusFinanzasApp: Permisos de notificación denegados")
                    // Desactivar la opción en configuración
                    UserDefaults.standard.set(false, forKey: "expenseNotificationsEnabled")
                }
            }
        }
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
                            initialCustomCategory: deepLinkHandler.prefilledCustomCategory,
                            initialCustomPaymentMethod: deepLinkHandler.prefilledCustomPaymentMethod,
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

// Delegate para mostrar notificaciones en foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Mostrar banner y sonido aunque la app esté en foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Detectar cuando el usuario pulsa la notificación
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let body = response.notification.request.content.body
        NotificationCenter.default.post(name: Notification.Name("ShowNotificationAlert"), object: body)
        // Guardar el mensaje en UserDefaults para mostrarlo si la vista aún no está lista
        UserDefaults.standard.set(body, forKey: "pendingNotificationMessage")
        completionHandler()
    }
} 
