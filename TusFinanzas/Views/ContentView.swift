import SwiftUI
import UIKit

// Este controlador nos permite detectar los toques en las pestañas
class TabBarController: UITabBarController, UITabBarControllerDelegate {
    var onTabReselected: ((Int) -> Void)?
    var onTabSelected: ((Int) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Este método se llama cuando se selecciona una nueva pestaña
        let index = tabBarController.selectedIndex
        print("TabBarController: didSelect - pestaña \(index)")
        onTabSelected?(index)
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Este método detecta cuando se toca una pestaña (incluso la actual)
        guard let idx = tabBar.items?.firstIndex(of: item) else { return }
        
        print("TabBarController: tabBar:didSelect - ítem \(idx)")
        
        // Si la pestaña tocada ya está seleccionada, es una reselección
        if idx == selectedIndex {
            print("TabBarController: Pestaña \(idx) reseleccionada")
            onTabReselected?(idx)
        }
    }
}

// Estructura representante UIKit para usar el TabBarController
struct TabBarControllerRepresentable: UIViewControllerRepresentable {
    var controllers: [UIViewController]
    @Binding var selectedIndex: Int
    var onTabReselected: ((Int) -> Void)?
    var onTabSelected: ((Int) -> Void)?
    
    func makeUIViewController(context: Context) -> TabBarController {
        let tabBarController = TabBarController()
        tabBarController.viewControllers = controllers
        tabBarController.onTabReselected = onTabReselected
        tabBarController.onTabSelected = onTabSelected
        return tabBarController
    }
    
    func updateUIViewController(_ uiViewController: TabBarController, context: Context) {
        // Solo actualizamos el índice seleccionado si es diferente
        // para evitar problemas con la recreación de vistas
        if uiViewController.selectedIndex != selectedIndex {
            print("TabBarControllerRepresentable: Actualizando selectedIndex de \(uiViewController.selectedIndex) a \(selectedIndex)")
            uiViewController.selectedIndex = selectedIndex
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Binding var selectedTab: Int
    @State private var showingResetConfirmation = false
    @Binding var navigateToGastosDiarios: Bool
    @State private var navigateToPropinas = false
    @State private var navigateToSuscripciones = false
    @State private var navigateToConfiguracion = false
    @State private var previousTab = 0 // Para detectar cambios de pestaña
    @State private var navigationReset = UUID() // Para forzar la recreación de la navegación
    @State private var lastTabSelection = Date() // Para detectar cuando se pulsa la misma pestaña
    @State private var showNotificationAlert = false
    @State private var notificationAlertMessage = ""
    @State private var showNotificationModal = false // Nueva variable para controlar el modal
    
    init(selectedTab: Binding<Int>, navigateToGastosDiarios: Binding<Bool>) {
        self._selectedTab = selectedTab
        self._navigateToGastosDiarios = navigateToGastosDiarios
    }
    
    private func formatCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM"
        
        // Obtener la fecha actual
        let currentDate = Date()
        
        // Si se debe mostrar el mes siguiente (después de un reset)
        if viewModel.showNextMonth {
            let calendar = Calendar.current
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                return formatter.string(from: nextMonth).uppercased()
            }
        }
        
        return formatter.string(from: currentDate).uppercased()
    }
    
    private func formatCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        
        // Obtener la fecha actual
        let currentDate = Date()
        
        // Si se debe mostrar el mes siguiente y es diciembre
        if viewModel.showNextMonth {
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: currentDate)
            
            if currentMonth == 12 {
                if let nextYear = calendar.date(byAdding: .year, value: 1, to: currentDate) {
                    return formatter.string(from: nextYear)
                }
            }
        }
        
        return formatter.string(from: currentDate)
    }
    
    private func sincronizarTotales() {
        print("ContentView: Iniciando sincronización de totales")
        if let tipTransaction = viewModel.findTipsTransaction() {
            print("ContentView: Transacción de propinas encontrada")
            let total = viewModel.getCurrentMonthTipsTotal(tipTransaction: tipTransaction)
            print("ContentView: Total calculado: \(total)€")
            
            // Actualizar la transacción con el nuevo total
            var updatedTransaction = tipTransaction
            updatedTransaction.amount = total
            
            if let index = viewModel.incomes.firstIndex(where: { $0.id == tipTransaction.id }) {
                viewModel.incomes[index] = updatedTransaction
                print("ContentView: Transacción actualizada correctamente")
            } else {
                print("ContentView: No se encontró el índice de la transacción")
            }
        } else {
            print("ContentView: No se encontró transacción de propinas")
        }
    }
    
    // Función para resetear la navegación de la pestaña "Más"
    private func resetMoreTabNavigation() {
        // Reiniciar la navegación al cambiar a la pestaña "Más"
        navigationReset = UUID()
        
        // Restablecer todas las flags de navegación cuando se pulsa sobre la pestaña "Más"
        navigateToGastosDiarios = false
        navigateToPropinas = false
        navigateToSuscripciones = false
        navigateToConfiguracion = false
        
        // Actualizar timestamp de la última selección
        lastTabSelection = Date()
        
        print("ContentView: Navegación de la pestaña Más reseteada")
    }
    
    private func handleTabSelection(index: Int) {
        print("ContentView: handleTabSelection - Pestaña \(index) seleccionada")
        
        // Actualizar el estado de la pestaña seleccionada
        previousTab = selectedTab
        selectedTab = index
        
        // Si se selecciona la pestaña "Más", resetear su navegación
        if index == 3 {
            print("ContentView: Tab 'Más' seleccionado - Reseteando navegación")
            resetMoreTabNavigation()
        }
    }
    
    private func handleTabReselection(index: Int) {
        print("ContentView: handleTabReselection - Pestaña \(index) reseleccionada")
        
        if index == 3 {
            // Si se tocó la pestaña "Más" cuando ya estaba seleccionada
            print("ContentView: Tab 'Más' reseleccionado - Reseteando navegación")
            resetMoreTabNavigation()
        }
    }
    
    var body: some View {
        // Creamos vistas para cada pestaña
        let incomesView = NavigationView {
            // Usar el array filtrado en lugar de acceder directamente a incomeTransactions
            // De esta manera, las propinas se mostrarán o no según la configuración
            let filteredIncomes = viewModel.getFilteredIncomesForDisplay()
            TransactionListView(
                transactions: Binding(
                    get: { 
                        // Forzar una evaluación completa cada vez que se accede
                        print("ContentView: Obteniendo ingresos filtrados - total: \(filteredIncomes.count)")
                        return viewModel.getFilteredIncomesForDisplay()
                    },
                    set: { viewModel.incomeTransactions = $0 }
                ),
                title: "Ingresos",
                pendingTotal: viewModel.pendingIncome,
                completedTotal: viewModel.completedIncome,
                total: viewModel.totalIncome,
                type: .income,
                selectedTab: $selectedTab,
                navigateToGastosDiarios: $navigateToGastosDiarios,
                navigateToPropinas: $navigateToPropinas,
                navigateToSuscripciones: $navigateToSuscripciones
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Ingresos")
                            .font(.title2)
                            .bold()
                        Text("\(formatCurrentMonth()) \(formatCurrentYear())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        
        let expensesView = NavigationView {
            TransactionListView(
                transactions: $viewModel.expenseTransactions,
                title: "Gastos",
                pendingTotal: viewModel.pendingExpenses,
                completedTotal: viewModel.completedExpenses,
                total: viewModel.totalExpenses,
                type: .expense,
                selectedTab: $selectedTab,
                navigateToGastosDiarios: $navigateToGastosDiarios,
                navigateToPropinas: $navigateToPropinas,
                navigateToSuscripciones: $navigateToSuscripciones
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Gastos")
                            .font(.title2)
                            .bold()
                        Text("\(formatCurrentMonth()) \(formatCurrentYear())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        
        let savingsView = NavigationView {
            SavingsView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        let moreView = NavigationView {
            MoreView(
                selectedTab: $selectedTab,
                navigateToGastosDiarios: $navigateToGastosDiarios,
                navigateToPropinas: $navigateToPropinas,
                navigateToSuscripciones: $navigateToSuscripciones,
                navigateToConfiguracion: $navigateToConfiguracion,
                navigationReset: navigationReset,
                lastTabSelection: $lastTabSelection
            )
        }
        .id(navigationReset) // Forzar la recreación de la vista
        
        // Convertimos nuestras vistas SwiftUI en ViewControllers de UIKit
        let incomesVC = UIHostingController(rootView: incomesView)
        let expensesVC = UIHostingController(rootView: expensesView)
        let savingsVC = UIHostingController(rootView: savingsView)
        let moreVC = UIHostingController(rootView: moreView)
        
        // Configuramos los elementos de la barra de pestañas
        incomesVC.tabBarItem = UITabBarItem(
            title: "Ingresos",
            image: UIImage(systemName: "arrow.down.circle"),
            selectedImage: UIImage(systemName: "arrow.down.circle.fill")
        )
        
        expensesVC.tabBarItem = UITabBarItem(
            title: "Gastos",
            image: UIImage(systemName: "arrow.up.circle"),
            selectedImage: UIImage(systemName: "arrow.up.circle.fill")
        )
        
        savingsVC.tabBarItem = UITabBarItem(
            title: "Ahorros",
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
        )
        
        moreVC.tabBarItem = UITabBarItem(
            title: "Más",
            image: UIImage(systemName: "ellipsis.circle"),
            selectedImage: UIImage(systemName: "ellipsis.circle.fill")
        )
        
        // Usamos nuestro TabBarController personalizado
        return TabBarControllerRepresentable(
            controllers: [incomesVC, expensesVC, savingsVC, moreVC],
            selectedIndex: $selectedTab,
            onTabReselected: handleTabReselection,
            onTabSelected: handleTabSelection
        )
        .ignoresSafeArea()
        .onChange(of: selectedTab) { newValue in
            // Cuando cambia la pestaña seleccionada mediante programación
            handleTabSelection(index: newValue)
        }
        .onChange(of: navigateToPropinas) { newValue in
            // Si activamos la navegación a Propinas y no estamos en la pestaña "Más",
            // cambiamos a la pestaña "Más"
            if newValue && selectedTab != 3 {
                selectedTab = 3
            }
        }
        .onChange(of: navigateToSuscripciones) { newValue in
            // Si activamos la navegación a Gastos de otras cuentas y no estamos en la pestaña "Más",
            // cambiamos a la pestaña "Más"
            if newValue && selectedTab != 3 {
                selectedTab = 3
            }
        }
        .onChange(of: navigateToGastosDiarios) { newValue in
            // Si activamos la navegación a Gastos Diarios y no estamos en la pestaña "Más",
            // cambiamos a la pestaña "Más"
            if newValue && selectedTab != 3 {
                selectedTab = 3
            }
        }
        .onChange(of: navigateToConfiguracion) { newValue in
            // Si activamos la navegación a Configuración y no estamos en la pestaña "Más",
            // cambiamos a la pestaña "Más"
            if newValue && selectedTab != 3 {
                selectedTab = 3
            }
        }
        .alert("Atención", isPresented: $showingResetConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer", role: .destructive) {
                viewModel.resetCompletedTransactions()
            }
        } message: {
            Text("Se restablecerán todos los conceptos a su estado original. ¿Está seguro de querer realizar esta operación?")
        }
        .sheet(isPresented: $showNotificationModal) {
            VStack(spacing: 20) {
                Text("Nueva alerta de gasto")
                    .font(.headline)
                    .padding(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parseNotificationMessage(notificationAlertMessage), id: \.self) { block in
                            switch block.type {
                            case .hoy:
                                Text(block.text)
                                    .font(.subheadline).foregroundColor(.blue).bold()
                                    .padding(.bottom, 4)
                            case .manana:
                                Text(block.text)
                                    .font(.subheadline).foregroundColor(.blue).bold()
                                    .padding(.top, 8).padding(.bottom, 4)
                            case .gasto:
                                // Extraer partes del gasto: '- Se cargará Concepto por importe de Importe€ a través de Método. Este gasto es Periodicidad.'
                                let gasto = parseGastoLine(block.text)
                                (
                                    Text(gasto.prefix)
                                        .font(.subheadline)
                                    + Text(gasto.concepto)
                                        .bold().font(.subheadline)
                                    + Text(gasto.intermedio)
                                        .font(.subheadline)
                                    + Text(gasto.importe)
                                        .italic().foregroundColor(.orange).font(.subheadline)
                                    + Text(gasto.sufijo)
                                        .font(.subheadline)
                                )
                                .padding(.bottom, 4)
                            case .totalHoy, .totalManana:
                                Text(block.text)
                                    .font(.subheadline).foregroundColor(.red).bold()
                                    .padding(.top, 4).padding(.bottom, 8)
                            case .otro:
                                Text(block.text)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .presentationDetents([.medium, .large])
                
                Button("OK") {
                    showNotificationModal = false
                    // Cambiar a la pestaña de Gastos (índice 1)
                    selectedTab = 1
                    // Limpiar el badge al cerrar el modal
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .onAppear {
                // Al mostrar el modal, cargar el mensaje completo de UserDefaults si existe
                if let fullMsg = UserDefaults.standard.string(forKey: "lastFullExpenseNotificationMessage") {
                    notificationAlertMessage = fullMsg
                }
                print("[DEBUG] Modal apareció con mensaje: \(notificationAlertMessage)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowNotificationAlert"))) { notif in
            if let msg = notif.object as? String {
                print("[DEBUG] Recibida notificación con mensaje: \(msg)")
                notificationAlertMessage = msg
                showNotificationModal = true
                // Borrar el mensaje pendiente si existe
                UserDefaults.standard.removeObject(forKey: "pendingNotificationMessage")
                // Limpiar el badge al mostrar el alert
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
        .onAppear {
            // Comprobar si hay un mensaje pendiente de notificación
            if let pendingMsg = UserDefaults.standard.string(forKey: "pendingNotificationMessage") {
                // Poner el badge a 1 si hay mensaje pendiente
                UIApplication.shared.applicationIconBadgeNumber = 1
                notificationAlertMessage = pendingMsg
                showNotificationModal = true // Usar el modal en lugar del alert
                UserDefaults.standard.removeObject(forKey: "pendingNotificationMessage")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(selectedTab: .constant(0), navigateToGastosDiarios: .constant(false))
    }
}

// Añadir la función auxiliar para parsear el mensaje y clasificar los bloques
fileprivate enum NotifBlockType { case hoy, manana, gasto, totalHoy, totalManana, otro }
fileprivate struct NotifBlock: Hashable { let type: NotifBlockType; let text: String }
fileprivate func parseNotificationMessage(_ msg: String) -> [NotifBlock] {
    var blocks: [NotifBlock] = []
    let lines = msg.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    var lastType: NotifBlockType = .otro
    for line in lines where !line.isEmpty {
        if line == "Hoy:" {
            blocks.append(.init(type: .hoy, text: line))
            lastType = .hoy
        } else if line == "Mañana:" {
            blocks.append(.init(type: .manana, text: line))
            lastType = .manana
        } else if line.hasPrefix("Total hoy:") {
            blocks.append(.init(type: .totalHoy, text: line))
            lastType = .totalHoy
        } else if line.hasPrefix("Total mañana:") {
            blocks.append(.init(type: .totalManana, text: line))
            lastType = .totalManana
        } else if line.hasPrefix("-") {
            blocks.append(.init(type: .gasto, text: line))
            lastType = .gasto
        } else {
            blocks.append(.init(type: .otro, text: line))
            lastType = .otro
        }
    }
    return blocks
}

// Añadir la función auxiliar para parsear la línea de gasto
fileprivate func parseGastoLine(_ line: String) -> (prefix: String, concepto: String, intermedio: String, importe: String, sufijo: String) {
    // Ejemplo de línea: '- Se cargará Basura Buenaventura por importe de 67.00€ a través de Transferencia. Este gasto es Anual.'
    let regex = try? NSRegularExpression(pattern: "^- Se cargará ([^\\n]+?) por importe de ([^\\s]+€)(.*)$", options: [])
    if let match = regex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
       let conceptoRange = Range(match.range(at: 1), in: line),
       let importeRange = Range(match.range(at: 2), in: line),
       let sufijoRange = Range(match.range(at: 3), in: line) {
        let prefix = "- Se cargará "
        let concepto = String(line[conceptoRange])
        let intermedio = " por importe de "
        let importe = String(line[importeRange])
        let sufijo = String(line[sufijoRange])
        return (prefix, concepto, intermedio, importe, sufijo)
    } else {
        // Si no matchea, devolver todo normal
        return ("", line, "", "", "")
    }
} 
