import SwiftUI

// Extensión para ocultar el teclado al tocar fuera del campo
extension View {
    func ocultarTeclado() {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.endEditing(true)
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

struct TipsView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var showingAddTips = false
    @State private var selectedWeek = Date()
    @State private var amount: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingClearConfirmation = false
    @State private var weekToDelete: Date?
    @State private var monthlyTotal: Double = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private func updateMonthlyTotal() {
        print("TipsView: Actualizando total mensual")
        let newTotal = calculateMonthlyTotal()
        print("TipsView: Nuevo total mensual: \(newTotal)€")
        
        DispatchQueue.main.async {
            self.monthlyTotal = newTotal
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
            }
            
            // Actualizar datos del widget
            WidgetDataProvider.shared.updateWidgetData()
        }
        
        // Forzar actualización de la UI
        DispatchQueue.main.async {
            self.updateMonthlyTotal()
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
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 15)
                
                // Historial del mes
                VStack(spacing: 10) {
                    ForEach(getWeeklyTips(), id: \.date) { weekTip in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedWeekRange(for: weekTip.date))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("(pulsa para eliminar)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.2f €", weekTip.amount))
                                .font(.subheadline)
                                .foregroundColor(.green)
                            
                            Button(action: {
                                weekToDelete = weekTip.date
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
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
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Botón para eliminar todos los registros
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                            Text("Eliminar todos los registros")
                                .font(.subheadline)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding(10)
                .background(Color(UIColor.tertiarySystemBackground))
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
        .onAppear {
            // Configurar el teclado
            UITextField.appearance().clearButtonMode = .whileEditing
            UITextField.appearance().tintColor = .white
            updateMonthlyTotal()
        }
        .sheet(isPresented: $showingAddTips) {
            WeekSelectorView(selectedDate: $selectedWeek)
        }
        .alert("Aviso", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Limpiar registros antiguos", isPresented: $showingClearConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Limpiar", role: .destructive) {
                let result = viewModel.clearPreviousTips()
                if result.success {
                    alertMessage = result.message ?? "Registros antiguos eliminados"
                } else {
                    alertMessage = result.message ?? "Error al limpiar los registros"
                }
                showingAlert = true
                
                // Forzar una actualización adicional de la interfaz
                DispatchQueue.main.async {
                    viewModel.refreshTotals()
                    updateMonthlyTotal()
                }
                
                // Actualizar datos del widget
                WidgetDataProvider.shared.updateWidgetData()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar todos los registros de propinas anteriores al mes actual? Esta acción no se puede deshacer.")
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Eliminar propinas"),
                message: Text("¿Estás seguro de que quieres eliminar las propinas de esta semana?"),
                primaryButton: .destructive(Text("Eliminar")) {
                    if let date = weekToDelete {
                        viewModel.deleteWeeklyTips(date: date)
                        
                        // Forzar una actualización adicional de la interfaz
                        DispatchQueue.main.async {
                            viewModel.refreshTotals()
                            updateMonthlyTotal()
                        }
                        
                        // Actualizar datos del widget
                        WidgetDataProvider.shared.updateWidgetData()
                    }
                },
                secondaryButton: .cancel()
            )
        }
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
 
 