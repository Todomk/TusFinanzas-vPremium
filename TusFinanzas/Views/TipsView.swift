import SwiftUI
import UIKit

// Extensión para ocultar el teclado al tocar fuera del campo
extension View {
    func ocultarTeclado() {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.endEditing(true)
    }
}

// Clase de utilidad para feedback háptico
class HapticManager {
    static let shared = HapticManager()
    
    // Retroalimentación de éxito
    func successFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Retroalimentación de error
    func errorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // Retroalimentación de eliminación
    func deleteFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// TipsWeeklyDataManager - Un ObservableObject dedicado para gestionar los datos de propinas
class TipsDataManager: ObservableObject {
    @Published var weeklySummaries: [(date: Date, amount: Double)] = []
    @Published var monthlyTotal: Double = 0
    
    var viewModel: FinanceViewModel
    
    init(viewModel: FinanceViewModel) {
        self.viewModel = viewModel
        refreshData()
    }
    
    func refreshData() {
        print("TipsDataManager: Refrescando datos...")
        guard let tipTransaction = viewModel.findTipsTransaction() else {
            print("TipsDataManager: No se encontró transacción de propinas")
            weeklySummaries = []
            monthlyTotal = 0
            return
        }
        
        weeklySummaries = viewModel.getWeeklySummaries(tipTransaction: tipTransaction)
        monthlyTotal = viewModel.getCurrentMonthTipsTotal(tipTransaction: tipTransaction)
        
        print("TipsDataManager: Datos actualizados - \(weeklySummaries.count) semanas, total: \(monthlyTotal)€")
    }
    
    func registrarPropina(amount: Double, date: Date, note: String) -> Bool {
        viewModel.addWeeklyTips(amount: amount, date: date, note: note)
        
        // Recargar datos después de registrar
        refreshData()
        
        return true
    }
}

// Vista independiente para el resumen semanal
struct WeeklySummaryView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var forceUpdate = UUID()
    
    var body: some View {
        VStack {
            // Si estamos mostrando el próximo mes y aún no hay registros, mostrar mensaje
            if viewModel.showNextMonth {
                // Resumen del próximo mes (nuevo ciclo) - inicialmente estará vacío
                if let summaries = getWeeklySummaries(), !summaries.isEmpty {
                    renderSummaries(summaries)
                } else {
                    Text("Nuevo ciclo iniciado. Aún no hay registros para este mes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                // Resumen del mes actual
                if let summaries = getWeeklySummaries(), !summaries.isEmpty {
                    renderSummaries(summaries)
                } else {
                    Text("No hay registros este mes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
        .id(forceUpdate) // Esto fuerza la reconstrucción completa de la vista
    }
    
    // Función para renderizar los summaries - extraída para evitar duplicación de código
    private func renderSummaries(_ summaries: [(date: Date, amount: Double)]) -> some View {
        VStack {
            ForEach(summaries, id: \.date) { summary in
                HStack {
                    Text(formattedWeek(from: summary.date))
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f €", summary.amount))
                        .font(.subheadline)
                        .bold()
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Total mensual
            HStack {
                Text("Total del mes")
                Spacer()
                Text(String(format: "%.2f €", getCurrentMonthTotal()))
                    .font(.title3)
                    .bold()
                    .foregroundColor(.green)
            }
            .padding(.top, 4)
        }
    }
    
    func updateView() {
        print("WeeklySummaryView: Actualizando vista")
        self.forceUpdate = UUID()
    }
    
    private func getCurrentMonthTotal() -> Double {
        guard let tipTransaction = viewModel.findTipsTransaction() else { 
            print("WeeklySummaryView: No hay transacción para total mensual")
            return 0 
        }
        let total = viewModel.getCurrentMonthTipsTotal(tipTransaction: tipTransaction)
        print("WeeklySummaryView: Total mensual calculado: \(total)€")
        return total
    }
    
    private func getWeeklySummaries() -> [(date: Date, amount: Double)]? {
        guard let tipTransaction = viewModel.findTipsTransaction() else {
            print("WeeklySummaryView: No hay transacción para resúmenes semanales")
            return nil
        }
        let summaries = viewModel.getWeeklySummaries(tipTransaction: tipTransaction)
        print("WeeklySummaryView: Encontrados \(summaries.count) resúmenes semanales")
        return summaries
    }
    
    private func formattedWeek(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Lunes como primer día
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }
}

// Un estado del restablecimiento completamente independiente
struct ResetButtonView: View {
    @EnvironmentObject var viewModel: FinanceViewModel 
    var onResetCompleted: () -> Void
    
    var body: some View {
        Button(action: {
            showResetPasswordFlow()
        }) {
            VStack(spacing: 2) {
                Text("Restablecer valores")
                    .font(.subheadline)
                    .foregroundColor(.red)
                
                Text("Poner contador a cero")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
        }
    }
    
    // Método que muestra directamente una alerta personalizada (no Sheet, no Alert de sistema)
    private func showResetPasswordFlow() {
        // Crear una ventana independiente para el popup
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Crear el controlador de vista para nuestro popup personalizado
            let hostingController = UIHostingController(
                rootView: ResetFlowView(viewModel: viewModel) { success in
                    // Callback cuando se completa el proceso
                    if success {
                        print("Restablecimiento completado con éxito")
                        onResetCompleted()
                    }
                    
                    // Cerrar el popup
                    rootViewController.dismiss(animated: true)
                }
            )
            
            // Configurar cómo se muestra
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            hostingController.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            
            // Mostrar el popup
            rootViewController.present(hostingController, animated: true)
        }
    }
}

// Vista del flujo de restablecimiento completamente independiente
struct ResetFlowView: View {
    @ObservedObject var viewModel: FinanceViewModel
    var onComplete: (Bool) -> Void
    
    @State private var step = 0
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error: String?
    
    var body: some View {
        ZStack {
            // Fondo semitransparente para oscurecer el resto de la app
            Color.black.opacity(0.01)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Opcional: cerrar al tocar fuera
                    // onComplete(false)
                }
            
            // Contenido principal
            VStack(spacing: 20) {
                // Cabecera con botón de cerrar
                HStack {
                    Spacer()
                    Button(action: {
                        onComplete(false)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .padding([.top, .trailing])
                }
                
                // Contenido que varía según el paso
                contenidoSegunPaso
                
                Spacer()
            }
            .frame(width: UIScreen.main.bounds.width - 60)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
            .padding(.horizontal, 30)
        }
    }
    
    // Contenido que cambia según el paso actual
    @ViewBuilder
    var contenidoSegunPaso: some View {
        switch step {
        case 0:
            pasoInicial
        case 1:
            pasoCrearContraseña
        case 2:
            pasoVerificarContraseña
        case 3:
            pasoProcesando
        case 4:
            pasoCompletado
        default:
            Text("Error en el flujo")
        }
    }
    
    // PASO 0: Vista inicial
    var pasoInicial: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .padding(.top)
            
            Text("Restablecer valores")
                .font(.headline)
            
            Text("Vas a restablecer todos los valores y comenzar un nuevo ciclo. Esta acción requiere confirmación mediante contraseña.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 5)
            
            Button(action: {
                if UserDefaults.standard.string(forKey: "resetPasswordKey") != nil {
                    // Ya existe contraseña, ir a verificación
                    step = 2
                } else {
                    // Primera vez, crear contraseña
                    step = 1
                }
            }) {
                Text("Continuar")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Button(action: {
                onComplete(false)
            }) {
                Text("Cancelar")
                    .foregroundColor(.gray)
            }
            .padding(.bottom)
        }
    }
    
    // PASO 1: Crear contraseña
    var pasoCrearContraseña: some View {
        VStack(spacing: 15) {
            Text("Crear contraseña de seguridad")
                .font(.headline)
                .padding(.top)
            
            Text("Esta contraseña será necesaria cada vez que quieras restablecer valores.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Contraseña (4 dígitos)")
                    .font(.caption)
                    .foregroundColor(.gray)
                SecureField("****", text: $password)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: password) { newValue in
                        validarInputNumerico(&password, newValue)
                    }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Confirmar contraseña")
                    .font(.caption)
                    .foregroundColor(.gray)
                SecureField("****", text: $confirmPassword)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: confirmPassword) { newValue in
                        validarInputNumerico(&confirmPassword, newValue)
                    }
            }
            .padding(.horizontal)
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: {
                if validarContraseñaCreada() {
                    // Guardar contraseña y continuar
                    UserDefaults.standard.set(password, forKey: "resetPasswordKey")
                    // Ir al paso de procesando
                    step = 3
                    // Ejecutar el restablecimiento
                    ejecutarRestablecimiento()
                }
            }) {
                Text("Establecer contraseña")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 5)
            
            Button(action: {
                step = 0
            }) {
                Text("Volver")
                    .foregroundColor(.gray)
            }
            .padding(.bottom)
        }
    }
    
    // PASO 2: Verificar contraseña
    var pasoVerificarContraseña: some View {
        VStack(spacing: 15) {
            Text("Verificar contraseña")
                .font(.headline)
                .padding(.top)
            
            Text("Introduce tu contraseña para confirmar el restablecimiento.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Contraseña (4 dígitos)")
                    .font(.caption)
                    .foregroundColor(.gray)
                SecureField("****", text: $password)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: password) { newValue in
                        validarInputNumerico(&password, newValue)
                    }
            }
            .padding(.horizontal)
            
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: {
                if validarContraseñaExistente() {
                    // Contraseña correcta, continuar
                    step = 3
                    // Ejecutar el restablecimiento
                    ejecutarRestablecimiento()
                }
            }) {
                Text("Verificar")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 5)
            
            Button(action: {
                step = 0
            }) {
                Text("Volver")
                    .foregroundColor(.gray)
            }
            .padding(.bottom)
        }
    }
    
    // PASO 3: Procesando
    var pasoProcesando: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Procesando restablecimiento...")
                .font(.headline)
        }
        .padding()
    }
    
    // PASO 4: Completado
    var pasoCompletado: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding(.top)
            
            Text("Restablecimiento completado")
                .font(.headline)
            
            Text("Todos los valores han sido restablecidos y se ha iniciado un nuevo ciclo correctamente.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .padding(.horizontal)
            
            Button(action: {
                onComplete(true)
            }) {
                Text("Aceptar")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
    }
    
    // FUNCIONES AUXILIARES
    
    // Validar y limitar input numérico
    private func validarInputNumerico(_ campo: inout String, _ nuevoValor: String) {
        if nuevoValor.count > 4 {
            campo = String(nuevoValor.prefix(4))
        }
        
        let filtrado = nuevoValor.filter { "0123456789".contains($0) }
        if filtrado != nuevoValor {
            campo = filtrado
        }
    }
    
    // Validar contraseña al crearla
    private func validarContraseñaCreada() -> Bool {
        if password.count != 4 {
            error = "La contraseña debe tener exactamente 4 dígitos."
            return false
        }
        
        if password != confirmPassword {
            error = "Las contraseñas no coinciden."
            return false
        }
        
        error = nil
        return true
    }
    
    // Validar contraseña existente
    private func validarContraseñaExistente() -> Bool {
        let contraseñaGuardada = UserDefaults.standard.string(forKey: "resetPasswordKey") ?? ""
        
        if password != contraseñaGuardada {
            error = "Contraseña incorrecta."
            return false
        }
        
        error = nil
        return true
    }
    
    // Ejecutar el restablecimiento
    private func ejecutarRestablecimiento() {
        // Añadimos un pequeño retraso para mejor feedback visual
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let resultado = viewModel.clearPreviousTips()
            
            if resultado.success {
                print("Restablecimiento exitoso")
                // Actualizar totales y widget
                viewModel.refreshTotals()
                WidgetDataProvider.shared.updateWidgetData()
                
                // Mostrar pantalla de éxito
                step = 4
            } else {
                // En caso de error, mostrar mensaje
                error = resultado.message ?? "Error al restablecer valores"
                step = 0
            }
        }
    }
}

struct TipsView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var showingAddTips = false
    @State private var selectedWeek = Date()
    @State private var amount: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var weekToDelete: Date?
    @State private var monthlyTotal: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var forceUpdate = UUID()
    @State private var arrastrandoItem: Date?
    @State private var offsetArrastre: CGFloat = 0
    
    // Enumeración para manejar diferentes tipos de alertas
    enum AlertType: Identifiable {
        case information(String)
        case deleteConfirmation(Date)
        
        var id: String {
            switch self {
                case .information:
                    return "information"
                case .deleteConfirmation(let date):
                    // Usar un valor único que incluya la marca de tiempo actual para evitar problemas de caché
                    return "delete_\(date.timeIntervalSince1970)_\(Date().timeIntervalSince1970)"
            }
        }
    }
    
    // Estado para manejar diferentes tipos de alertas
    @State private var activeAlert: AlertType?
    @State private var showDeleteConfirmation = false
    @State private var dateToDelete: Date?
    
    // Método para resetear los estados de deslizamiento
    private func resetSwipeStates() {
        self.arrastrandoItem = nil
        self.offsetArrastre = 0
    }
    
    private func updateMonthlyTotal() {
        print("TipsView: Actualizando total mensual")
        let newTotal = calculateMonthlyTotal()
        print("TipsView: Nuevo total mensual: \(newTotal)€")
        
        DispatchQueue.main.async {
            self.monthlyTotal = newTotal
            // Resetear los estados de deslizamiento para evitar que queden botones desplegados
            self.resetSwipeStates()
        }
    }
    
    private func formattedWeekRange(for date: Date? = nil) -> String {
        let targetDate = date ?? selectedWeek
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }
    
    private func formatCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }
    
    private func getWeeklyTips() -> [(date: Date, amount: Double)] {
        guard let tipTransaction = viewModel.findTipsTransaction() else {
            return []
        }
        return viewModel.getWeeklySummaries(tipTransaction: tipTransaction)
    }
    
    private func getReferenceDate() -> Date {
        // Si estamos mostrando el próximo mes, usar la fecha del próximo mes, sino usar la fecha actual
        if viewModel.showNextMonth {
            let calendar = Calendar.current
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        }
        return Date()
    }
    
    private func calculateMonthlyTotal() -> Double {
        guard let tipTransaction = viewModel.findTipsTransaction() else {
            print("TipsView: No hay transacción para calcular total mensual")
            return 0
        }
        
        // Obtener la fecha de referencia (actual o futura)
        let referenceDate = getReferenceDate()
        print("TipsView: Calculando total para fecha de referencia: \(referenceDate)")
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Lunes como primer día
        
        // Sumar todas las cantidades del listado
        let total = getWeeklyTips().reduce(0) { sum, weekTip in
            return sum + weekTip.amount
        }
        
        print("TipsView: Total mensual calculado: \(total)€")
        
        DispatchQueue.main.async {
            self.monthlyTotal = total
        }
        
        return total
    }
    
    private func addWeeklyTips(amount: Double, date: Date) {
        print("TipsView: Iniciando registro de propina")
        print("TipsView: Cantidad a registrar: \(amount)€")
        print("TipsView: Fecha seleccionada: \(date)")
        print("TipsView: Fecha de referencia: \(getReferenceDate())")
        
        // Verificar si existe la transacción de propinas
        if let existingTransaction = viewModel.findTipsTransaction() {
            print("TipsView: Transacción de propinas existente encontrada")
            print("TipsView: ID de transacción: \(existingTransaction.id)")
            print("TipsView: Número de registros: \(existingTransaction.weeklyAmounts?.count ?? 0)")
        } else {
            print("TipsView: No existe transacción de propinas, se creará una nueva")
        }
        
        viewModel.addWeeklyTips(amount: amount, date: date, note: "")
        
        // Verificar si la transacción se actualizó correctamente
        if let updatedTransaction = viewModel.findTipsTransaction() {
            print("TipsView: Transacción actualizada - ID: \(updatedTransaction.id)")
            print("TipsView: Número de registros después de actualizar: \(updatedTransaction.weeklyAmounts?.count ?? 0)")
            
            // Calcular y actualizar el total mensual
            let newTotal = calculateMonthlyTotal()
            print("TipsView: Nuevo total mensual calculado: \(newTotal)€")
            
            // Forzar una actualización adicional de la interfaz
            DispatchQueue.main.async {
                viewModel.refreshTotals()
                updateMonthlyTotal()
                // Resetear los estados de deslizamiento para que los nuevos elementos se muestren correctamente
                resetSwipeStates()
                // Forzar la reconstrucción completa de la vista
                self.forceUpdate = UUID()
            }
            
            // Actualizar datos del widget
            WidgetDataProvider.shared.updateWidgetData()
        }
        
        // Forzar actualización de la UI
        DispatchQueue.main.async {
            self.updateMonthlyTotal()
            // Garantizar que se resetean los estados de deslizamiento
            self.resetSwipeStates()
            // Forzar reconstrucción de la vista
            self.forceUpdate = UUID()
        }
    }
    
    // Método para mostrar la alerta de confirmación
    private func showConfirmDeleteAlert(for date: Date) {
        print("TipsView: Solicitando confirmación para eliminar propina del \(date)")
        self.dateToDelete = date
        self.showDeleteConfirmation = true
    }
    
    // Método para ejecutar la eliminación después de la confirmación
    private func performDelete() {
        guard let date = dateToDelete else { return }
        
        print("TipsView: Ejecutando eliminación confirmada para \(date)")
        let success = viewModel.deleteWeeklyTips(date: date)
        
        // Proporcionar feedback háptico
        if success {
            HapticManager.shared.successFeedback()
        } else {
            HapticManager.shared.errorFeedback()
        }
        
        // Actualizar UI después de eliminar
        if success {
            DispatchQueue.main.async {
                self.updateMonthlyTotal()
                viewModel.refreshTotals()
                self.forceUpdate = UUID()
                // Resetear los estados de deslizamiento
                self.resetSwipeStates()
                WidgetDataProvider.shared.updateWidgetData()
            }
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12, pinnedViews: []) {
                Spacer()
                    .frame(height: 8)
                    
                // Registro rápido contenido
                VStack(spacing: 12) {
                    // Selector de semana
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Semana seleccionada")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formattedWeekRange())
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddTips = true
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                Text("cambiar")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Campo de cantidad
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cantidad")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.headline)
                                .foregroundColor(.white)
                                .onChange(of: amount) { newValue in
                                    // Permitir solo números, punto y coma
                                    let filtered = newValue.filter { "0123456789,.".contains($0) }
                                    if filtered != newValue {
                                        amount = filtered
                                    }
                                    
                                    // Reemplazar comas por puntos
                                    if filtered.contains(",") {
                                        amount = filtered.replacingOccurrences(of: ",", with: ".")
                                    }
                                    
                                    // Limitar a dos decimales
                                    let components = filtered.components(separatedBy: ".")
                                    if components.count > 1 {
                                        let decimalPart = components[1]
                                        if decimalPart.count > 2 {
                                            amount = String(filtered.prefix(components[0].count + 3))
                                        }
                                    }
                                }
                            Text("€")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Botón de registro
                    Button(action: {
                        // Limpiar espacios y convertir comas a puntos
                        let cleanAmount = amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                        
                        if let amountValue = Double(cleanAmount), amountValue >= 0 {
                            print("TipsView: Valor válido introducido: \(amountValue)€")
                            let result = viewModel.addWeeklyTips(amount: amountValue, date: selectedWeek, note: "")
                            
                            if result.success {
                                amount = ""
                                // Ocultar el teclado de forma segura
                                ocultarTeclado()
                                
                                // Forzar una actualización adicional de la interfaz
                                DispatchQueue.main.async {
                                    viewModel.refreshTotals()
                                    updateMonthlyTotal()
                                }
                                
                                // Actualizar datos del widget
                                WidgetDataProvider.shared.updateWidgetData()
                            } else if let message = result.message {
                                alertMessage = message
                                showingAlert = true
                            }
                        } else {
                            print("TipsView: Valor inválido introducido: \(amount)")
                            alertMessage = "Por favor, introduce una cantidad válida"
                            showingAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.black)
                            Text("Registrar propinas")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 15)
                
                // Historial del mes
                VStack(spacing: 10) {
                    ForEach(getWeeklyTips(), id: \.date) { weekTip in
                        ZStack {
                            // Fondo rojo que aparece al deslizar
                            HStack {
                                Spacer()
                                Button(action: {
                                    // En lugar de eliminar directamente, mostrar alerta de confirmación
                                    showConfirmDeleteAlert(for: weekTip.date)
                                    
                                    // Proporcionar feedback háptico al mostrar la confirmación
                                    HapticManager.shared.deleteFeedback()
                                    
                                    // Restaurar la posición del ítem
                                    if arrastrandoItem == weekTip.date {
                                        arrastrandoItem = nil
                                        offsetArrastre = 0
                                    }
                                }) {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 90, height: 80)
                                }
                                .background(Color.red)
                            }
                            
                            // Contenido principal (desplazable)
                            GeometryReader { geometry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formattedWeekRange(for: weekTip.date))
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text("(desliza para eliminar)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.2f €", weekTip.amount))
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(12)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .background(Color.black.opacity(0.8))
                                .offset(x: self.calculaOffset(weekTip: weekTip))
                                .gesture(
                                    DragGesture()
                                        .onChanged { gesture in
                                            if gesture.translation.width < 0 {
                                                // Guardar la posición actual del arrastre
                                                arrastrandoItem = weekTip.date
                                                offsetArrastre = gesture.translation.width
                                            }
                                        }
                                        .onEnded { value in
                                            // Si el deslizamiento es suficientemente largo hacia la izquierda
                                            if value.translation.width < -100 {
                                                // Mostrar alerta de confirmación en lugar de eliminar directamente
                                                showConfirmDeleteAlert(for: weekTip.date)
                                                
                                                // Proporcionar feedback háptico al mostrar la confirmación
                                                HapticManager.shared.deleteFeedback()
                                            } else {
                                                // Cancelar el deslizamiento
                                                if arrastrandoItem == weekTip.date {
                                                    arrastrandoItem = nil
                                                    offsetArrastre = 0
                                                }
                                            }
                                        }
                                )
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: self.calculaOffset(weekTip: weekTip))
                            }
                        }
                        .frame(height: 60)
                        .cornerRadius(10)
                        .clipped() // Asegura que el contenido no se desborde
                        // Forzar posición normal cuando cambia forceUpdate
                        .id("\(weekTip.date.timeIntervalSince1970)_\(forceUpdate)")
                    }
                    
                    if getWeeklyTips().isEmpty {
                        Text("No hay propinas registradas este mes")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    
                    // Total mensual
                    HStack {
                        Text("Total del mes")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text(String(format: "%.2f €", monthlyTotal))
                            .font(.headline)
                            .bold()
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    
                    // REEMPLAZADO: Botón para restablecer valores
                    // Ahora usamos nuestro componente personalizado
                    ResetButtonView {
                        // Actualizar UI después del restablecimiento
                        updateMonthlyTotal()
                    }
                    .environmentObject(viewModel)
                }
                .padding(10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 15)
            }
        }
        .background(Color.black)
        .navigationTitle("\(formatCurrentMonth())")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            ocultarTeclado()
        }
        .padding(.bottom, 1)
        .onAppear {
            // Configurar el teclado
            UITextField.appearance().clearButtonMode = .whileEditing
            UITextField.appearance().tintColor = .white
            updateMonthlyTotal()
            // Asegurar que al aparecer la vista, todos los elementos están en posición normal
            resetSwipeStates()
        }
        .sheet(isPresented: $showingAddTips) {
            WeekSelectorView(selectedDate: $selectedWeek)
        }
        .id(forceUpdate) // Forzar reconstrucción de la vista cuando cambia forceUpdate
        // Alerta unificada
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .information(let message):
                return Alert(
                    title: Text("Información"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        DispatchQueue.main.async {
                            updateMonthlyTotal()
                        }
                    }
                )
            case .deleteConfirmation(let date):
                return Alert(
                    title: Text("Eliminar propinas"),
                    message: Text("¿Estás seguro de que quieres eliminar las propinas de esta semana?"),
                    primaryButton: .destructive(Text("Eliminar")) {
                        performDelete()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        // Alerta separada para mensajes genéricos
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Información"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    DispatchQueue.main.async {
                        updateMonthlyTotal()
                    }
                }
            )
        }
        // Nueva alerta de confirmación para eliminar
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Eliminar propinas"),
                message: Text("¿Estás seguro de que quieres eliminar las propinas de esta semana?"),
                primaryButton: .destructive(Text("Eliminar")) {
                    performDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func calculaOffset(weekTip: (date: Date, amount: Double)) -> CGFloat {
        if let arrastrandoItem = arrastrandoItem, arrastrandoItem == weekTip.date {
            return offsetArrastre
        }
        return 0
    }
}

// Vista para mostrar un mensaje de éxito
struct SuccessOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text(message)
                .font(.headline)
                .padding(.top, 10)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(radius: 4)
        )
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onDismiss()
            }
        }
    }
}

// Vista de gráfico para mostrar la evolución de las propinas
struct TipsChartView: View {
    let weeklySummaries: [(date: Date, amount: Double)]
    
    var body: some View {
        VStack {
            if !weeklySummaries.isEmpty {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklySummaries.indices, id: \.self) { index in
                        let summary = weeklySummaries[index]
                        let height = getHeight(for: summary.amount)
                        
                        VStack {
                            // Barra del gráfico
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: 30, height: height)
                            
                            // Etiqueta de semana
                            Text("S\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 150)
                .padding(.vertical)
            } else {
                Text("No hay datos para mostrar")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private func getHeight(for amount: Double) -> CGFloat {
        // Encontrar el valor máximo para escalar correctamente
        guard !weeklySummaries.isEmpty else { return 0 }
        let maxAmount = weeklySummaries.map { $0.amount }.max() ?? 1
        
        // Calcular la altura proporcional (máximo 120 puntos)
        return CGFloat(amount / maxAmount) * 120
    }
}

struct WeekSelectorView: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Selecciona la semana",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirmar")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Seleccionar semana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct TipsView_Previews: PreviewProvider {
    static var previews: some View {
        TipsView()
            .environmentObject(FinanceViewModel())
    }
} 
 
 