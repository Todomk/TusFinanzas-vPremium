import SwiftUI

struct MoreView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Binding var selectedTab: Int
    @Binding var navigateToGastosDiarios: Bool
    @Binding var navigateToPropinas: Bool
    @Binding var navigateToSuscripciones: Bool
    @Binding var navigateToConfiguracion: Bool
    var navigationReset: UUID = UUID() // Para forzar la recreación de la vista
    @Binding var lastTabSelection: Date // Timestamp para detectar pulsos directos en la tab
    
    // Estados para controlar qué vista se muestra
    @State private var showSuscripciones = false
    @State private var showPropinas = false
    @State private var showGastosDiarios = false
    @State private var showConfiguracion = false
    
    private func formatCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date()).uppercased()
    }
    
    private func formatCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    // Función para resetear todos los estados de navegación
    private func resetNavigation() {
        showSuscripciones = false
        showPropinas = false
        showGastosDiarios = false
        showConfiguracion = false
    }
    
    var body: some View {
        ZStack {
            // Vista de la pestaña Más (nivel principal)
            if !showSuscripciones && !showPropinas && !showGastosDiarios && !showConfiguracion {
                NavigationView {
                    List {
                        Section(header: Text("Gestión")) {
                            Button {
                                print("MoreView: Navegando a Gastos de otras cuentas")
                                showSuscripciones = true
                            } label: {
                                HStack {
                                    Image(systemName: "creditcard.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Gastos de otras cuentas")
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        // Total de gastos de otras cuentas (pendientes + completadas)
                                        let totalSuscripciones = viewModel.pendingSubscriptions + viewModel.completedSubscriptions
                                        Text(String(format: "%.2f €", totalSuscripciones))
                                            .foregroundColor(.blue)
                                        
                                        // Cantidad pagada
                                        Text("Pagado: \(String(format: "%.2f", viewModel.completedSubscriptions))€")
                                            .font(.system(size: 9))
                                            .foregroundColor(.green)
                                        
                                        // Cantidad pendiente
                                        Text("Pendiente: \(String(format: "%.2f", viewModel.pendingSubscriptions))€")
                                            .font(.system(size: 9))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        
                        // Solo mostrar la opción de Propinas si está activada en configuración
                        if viewModel.showTips {
                            Button {
                                print("MoreView: Navegando a Propinas")
                                showPropinas = true
                            } label: {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Propinas")
                                    Spacer()
                                    if let tipsTransaction = viewModel.findTipsTransaction(),
                                       let weeklyAmounts = tipsTransaction.weeklyAmounts {
                                        let total = weeklyAmounts.values.reduce(0) { $0 + $1 }
                                        Text(String(format: "%.2f €", total))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        Button {
                            print("MoreView: Navegando a Gastos diarios")
                            showGastosDiarios = true
                        } label: {
                            HStack {
                                Image(systemName: "fuelpump.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Gastos diarios")
                                Spacer()
                                if !viewModel.gpTransactions.isEmpty {
                                    Text(String(format: "%.2f €", viewModel.gpTransactions.reduce(0) { $0 + $1.amount }))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Section(header: Text("Aplicación")) {
                            Button {
                                print("MoreView: Navegando a Configuración")
                                showConfiguracion = true
                            } label: {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(.gray)
                                    Text("Configuración")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Más")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text("Más")
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
            
            // Vista de Gastos de otras cuentas
            if showSuscripciones {
                NavigationView {
                    TransactionListView(
                        transactions: $viewModel.subscriptions,
                        title: "Gastos de otras cuentas",
                        pendingTotal: viewModel.pendingSubscriptions,
                        completedTotal: viewModel.completedSubscriptions,
                        total: viewModel.totalSubscriptions,
                        type: .subscription,
                        selectedTab: $selectedTab
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showSuscripciones = false
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing))
            }
            
            // Vista de Propinas
            if showPropinas {
                NavigationView {
                    TipsView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showPropinas = false
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing))
            }
            
            // Vista de Gastos Diarios
            if showGastosDiarios {
                NavigationView {
                    GPTransactionListView(
                        transactions: $viewModel.gpTransactions,
                        selectedTab: $selectedTab
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showGastosDiarios = false
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing))
            }
            
            // Vista de Configuración
            if showConfiguracion {
                NavigationView {
                    ConfiguracionView()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                showConfiguracion = false
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(Circle())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing))
            }
        }
        .id(navigationReset) // Forzar la recreación de la vista
        .onAppear {
            print("MoreView: onAppear")
            // Comprobar si hay navegación pendiente
            checkPendingNavigation()
        }
        .onChange(of: navigationReset) { _ in
            print("MoreView: navigationReset cambió - Reiniciando navegación")
            resetNavigation()
        }
        .onChange(of: lastTabSelection) { _ in
            print("MoreView: lastTabSelection cambió - Reiniciando navegación")
            resetNavigation()
        }
        .onChange(of: navigateToPropinas) { newValue in
            if newValue {
                print("MoreView: navigateToPropinas activado")
                // Solo navegamos a propinas si está activada la opción
                if viewModel.showTips {
                    resetNavigation()
                    showPropinas = true
                } else {
                    print("MoreView: Navegación a propinas cancelada - showTips está desactivado")
                }
                // Reset the flag after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToPropinas = false
                }
            }
        }
        .onChange(of: navigateToSuscripciones) { newValue in
            if newValue {
                print("MoreView: navigateToSuscripciones activado")
                resetNavigation()
                showSuscripciones = true
                // Reset the flag after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToSuscripciones = false
                }
            }
        }
        .onChange(of: navigateToGastosDiarios) { newValue in
            if newValue {
                print("MoreView: navigateToGastosDiarios activado")
                resetNavigation()
                showGastosDiarios = true
                // Reset the flag after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToGastosDiarios = false
                }
            }
        }
        .onChange(of: navigateToConfiguracion) { newValue in
            if newValue {
                print("MoreView: navigateToConfiguracion activado")
                resetNavigation()
                showConfiguracion = true
                // Reset the flag after navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToConfiguracion = false
                }
            }
        }
    }
    
    // Comprueba si hay alguna navegación pendiente
    private func checkPendingNavigation() {
        if navigateToPropinas {
            print("MoreView: Navegación pendiente a Propinas")
            // Solo navegamos a propinas si está activada la opción
            if viewModel.showTips {
                resetNavigation()
                showPropinas = true
            } else {
                print("MoreView: Navegación a propinas cancelada - showTips está desactivado")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToPropinas = false
            }
        } else if navigateToSuscripciones {
            print("MoreView: Navegación pendiente a Gastos de otras cuentas")
            resetNavigation()
            showSuscripciones = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToSuscripciones = false
            }
        } else if navigateToGastosDiarios {
            print("MoreView: Navegación pendiente a Gastos diarios")
            resetNavigation()
            showGastosDiarios = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToGastosDiarios = false
            }
        } else if navigateToConfiguracion {
            print("MoreView: Navegación pendiente a Configuración")
            resetNavigation()
            showConfiguracion = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToConfiguracion = false
            }
        }
    }
} 
