import SwiftUI

// Vista para el botón de Gastos Diarios
struct GastosDiariosButton: View {
    let action: () -> Void
    let amount: Double
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(.orange)
                Text("Gastos diarios")
                Spacer()
                Text(String(format: "%.2f €", amount))
                    .foregroundColor(.orange)
            }
        }
    }
}

// Vista para el botón de Propinas
struct PropinasButton: View {
    let action: () -> Void
    let tipsTransaction: Transaction?
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Propinas")
                Spacer()
                if let transaction = tipsTransaction,
                   let weeklyAmounts = transaction.weeklyAmounts {
                    let total = weeklyAmounts.values.reduce(0) { $0 + $1 }
                    Text(String(format: "%.2f €", total))
                        .foregroundColor(.green)
                }
            }
        }
    }
}

// Vista para el botón de Mi Cuenta
struct MyAccountButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                Text("Mi Cuenta")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Vista para el botón de Configuración
struct ConfiguracionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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

// Vista principal de la lista
struct MainListView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    let showGastosDiarios: () -> Void
    let showPropinas: () -> Void
    let showMyAccount: () -> Void
    let showConfiguracion: () -> Void
    let month: String
    let year: String
    
    var body: some View {
        List {
            Section(header: Text("Gestión")) {
                GastosDiariosButton(
                    action: showGastosDiarios,
                    amount: viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                )
                
                if viewModel.showTips {
                    PropinasButton(
                        action: showPropinas,
                        tipsTransaction: viewModel.findTipsTransaction()
                    )
                }
            }
            
            Section(header: Text("Aplicación")) {
                MyAccountButton(action: showMyAccount)
                ConfiguracionButton(action: showConfiguracion)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Más")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("\(month) \(year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Vista de navegación para cada sección
struct NavigationContainerView: View {
    let content: AnyView
    let backAction: () -> Void
    
    var body: some View {
        NavigationView {
            content
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: backAction) {
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

struct MoreView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Binding var selectedTab: Int
    @Binding var navigateToGastosDiarios: Bool
    @Binding var navigateToPropinas: Bool
    @Binding var navigateToSuscripciones: Bool
    @Binding var navigateToConfiguracion: Bool
    var navigationReset: UUID = UUID()
    @Binding var lastTabSelection: Date
    
    @State private var showPropinas = false
    @State private var showGastosDiarios = false
    @State private var showMyAccount = false
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
    
    private func resetNavigation() {
        showPropinas = false
        showGastosDiarios = false
        showMyAccount = false
        showConfiguracion = false
    }
    
    var mainView: some View {
        NavigationView {
            MainListView(
                showGastosDiarios: { showGastosDiarios = true },
                showPropinas: { showPropinas = true },
                showMyAccount: { showMyAccount = true },
                showConfiguracion: { showConfiguracion = true },
                month: formatCurrentMonth(),
                year: formatCurrentYear()
            )
        }
        .navigationViewStyle(.stack)
    }
    
    var propinasView: some View {
        NavigationContainerView(
            content: AnyView(
                TipsView()
            ),
            backAction: { showPropinas = false }
        )
    }
    
    var gastosDiariosView: some View {
        NavigationContainerView(
            content: AnyView(
                GPTransactionListView(
                    transactions: $viewModel.gpTransactions,
                    selectedTab: $selectedTab
                )
            ),
            backAction: { showGastosDiarios = false }
        )
    }
    
    var myAccountView: some View {
        NavigationContainerView(
            content: AnyView(MyAccountView(isPresented: $showMyAccount)),
            backAction: { showMyAccount = false }
        )
    }
    
    var configuracionView: some View {
        NavigationContainerView(
            content: AnyView(ConfiguracionView()),
            backAction: { showConfiguracion = false }
        )
    }
    
    var body: some View {
        ZStack {
            if !showPropinas && !showGastosDiarios && !showMyAccount && !showConfiguracion {
                mainView
            }
            if showPropinas {
                propinasView
            }
            if showGastosDiarios {
                gastosDiariosView
            }
            if showMyAccount {
                myAccountView
            }
            if showConfiguracion {
                configuracionView
            }
        }
        .id(navigationReset)
        .onAppear {
            print("MoreView: onAppear")
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
                if viewModel.showTips {
                    resetNavigation()
                    showPropinas = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToPropinas = false
                }
            }
        }
        .onChange(of: navigateToSuscripciones) { newValue in
            if newValue {
                print("MoreView: navigateToSuscripciones activado")
                resetNavigation()
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigateToConfiguracion = false
                }
            }
        }
    }
    
    private func checkPendingNavigation() {
        if navigateToPropinas {
            print("MoreView: Navegación pendiente a Propinas")
            if viewModel.showTips {
                resetNavigation()
                showPropinas = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigateToPropinas = false
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
