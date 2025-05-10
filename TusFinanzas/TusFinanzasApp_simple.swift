import SwiftUI

// Una versión simplificada de ContentView para depurar
struct SimpleContentView: View {
    @Binding var selectedTab: Int
    @Binding var navigateToGastosDiarios: Bool
    
    var body: some View {
        Text("Tab: \(selectedTab), Navegar: \(navigateToGastosDiarios ? "Sí" : "No")")
    }
}

// Quitado el atributo @main para evitar conflictos
struct TusFinanzasAppSimple: App {
    @State private var selectedTab = 0
    @State private var navigateToGastosDiarios = false
    
    var body: some Scene {
        WindowGroup {
            SimpleContentView(
                selectedTab: $selectedTab,
                navigateToGastosDiarios: $navigateToGastosDiarios
            )
        }
    }
} 