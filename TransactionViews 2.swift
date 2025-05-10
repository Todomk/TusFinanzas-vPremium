import SwiftUI

struct AddTransactionView: View {
    let type: TransactionType
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String = ""
    @State private var concept: String = ""
    @State private var periodicity: Periodicity = .monthly
    @State private var paymentType: PaymentType = .manual
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String = "Efectivo"
    @State private var startDate: Date = Date()
    @State private var showingDatePicker = false
    
    // Variables para pagos automáticos
    @State private var automaticPaymentOption: AutomaticPaymentOption = .specificDay
    @State private var paymentDay: Int = Calendar.current.component(.day, from: Date())
    @State private var specificWeekDay: WeekDay = .monday
    
    // Nuevos campos para gestionar el fin del pago
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var showingEndDatePicker = false
    @State private var endDateType: EndDateType = .duration
    @State private var durationValue: Int = 12
    @State private var durationType: DurationType = .months
    
    // Enumeraciones para los tipos de fin de pago
    enum EndDateType: String, CaseIterable {
        case specific = "Fecha específica"
        case duration = "Duración"
    }
    
    enum DurationType: String, CaseIterable {
        case months = "Meses"
        case years = "Años"
    }
    
    init(type: TransactionType) {
        self.type = type
        
        // Inicializar el valor del método de pago
        _selectedPaymentMethodString = State(initialValue: PaymentMethod.cash.rawValue)
    }
    
    // Función para calcular la fecha de fin basada en la duración
    private func calculateEndDate() -> Date {
        let calendar = Calendar.current
        
        switch durationType {
        case .months:
            if let calculatedDate = calendar.date(byAdding: .month, value: durationValue, to: startDate) {
                return calculatedDate
            }
        case .years:
            if let calculatedDate = calendar.date(byAdding: .year, value: durationValue, to: startDate) {
                return calculatedDate
            }
        }
        
        // Si no se puede calcular, usar fecha actual + 1 año como fallback
        return calendar.date(byAdding: .year, value: 1, to: startDate) ?? Date()
    }
    
    // Formatea la duración para mostrarla
    private func formatDuration() -> String {
        let unit = durationValue == 1 ? 
                  (durationType == .months ? "mes" : "año") : 
                  (durationType == .months ? "meses" : "años")
        return "\(durationValue) \(unit)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Información básica")) {
                    HStack {
                        TextField("Concepto", text: $concept)
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        TextField("Cantidad", text: $amount)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { newValue in
                                // Filtrar para permitir solo números y hasta 2 decimales
                                let filtered = newValue.filter { "0123456789.,".contains($0) }
                                
                                // Reemplazar comas por puntos
                                var formatted = filtered.replacingOccurrences(of: ",", with: ".")
                                
                                // Asegurar que solo hay un punto decimal
                                if formatted.components(separatedBy: ".").count > 2 {
                                    let components = formatted.components(separatedBy: ".")
                                    formatted = components.first! + "." + components.dropFirst().joined()
                                }
                                
                                // Limitar a 2 decimales
                                if let dotIndex = formatted.firstIndex(of: ".") {
                                    let decimalPart = formatted[formatted.index(after: dotIndex)...]
                                    if decimalPart.count > 2 {
                                        let endIndex = formatted.index(dotIndex, offsetBy: 3)
                                        formatted = String(formatted[..<endIndex])
                                    }
                                }
                                
                                // Actualizar el valor si es diferente
                                if formatted != newValue {
                                    amount = formatted
                                }
                            }
                        Text("€")
                            .foregroundColor(.secondary)
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Configuración")) {
                    Picker("Periodicidad", selection: $periodicity) {
                        ForEach(Periodicity.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    
                    Picker("Tipo de pago", selection: $paymentType) {
                        ForEach(PaymentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Método de pago", selection: $selectedPaymentMethodString) {
                        // Mostrar todos los métodos de pago disponibles
                        ForEach(viewModel.getAllPaymentMethods(), id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .onChange(of: selectedPaymentMethodString) { newValue in
                        // Buscar si coincide con algún método estándar
                        if let standardMethod = PaymentMethod.allCases.first(where: { $0.rawValue == newValue }) {
                            paymentMethod = standardMethod
                            customPaymentMethod = nil
                        } else {
                            // Es un método personalizado
                            paymentMethod = .custom
                            customPaymentMethod = newValue
                        }
                    }
                    
                    Button(action: { showingDatePicker = true }) {
                        HStack {
                            Text(type == .income ? "Fecha de ingreso" : "Fecha de inicio")
                            Spacer()
                            Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Sección para la fecha de finalización (para todos los tipos)
                Section(header: Text("Finalización")) {
                    Toggle("Tiene fecha de finalización", isOn: $hasEndDate)
                    
                    if hasEndDate {
                        Picker("Tipo de finalización", selection: $endDateType) {
                            ForEach(EndDateType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                        if endDateType == .specific {
                            Button(action: { showingEndDatePicker = true }) {
                                HStack {
                                    Text("Fecha de finalización")
                                    Spacer()
                                    Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Duración en meses o años
                            Stepper(value: $durationValue, in: 1...60) {
                                HStack {
                                    Text("Duración")
                                    Spacer()
                                    Text(formatDuration())
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Picker("Unidad", selection: $durationType) {
                                ForEach(DurationType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            
                            // Mostrar la fecha calculada
                            HStack {
                                Text("Fecha de finalización")
                                Spacer()
                                Text(calculateEndDate().formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(type == .income ? "Nuevo ingreso" : (type == .subscription ? "Nueva suscripción" : "Nuevo gasto"))
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Guardar") {
                    if let amount = Double(amount),
                       !concept.isEmpty {
                        var transaction = Transaction(
                            amount: amount,
                            concept: concept,
                            type: type,
                            periodicity: periodicity,
                            paymentType: paymentType,
                            paymentMethod: paymentMethod,
                            customPaymentMethod: customPaymentMethod
                        )
                        
                        // Configurar fechas según el tipo de transacción
                        transaction.startDate = startDate
                        
                        // Configurar automáticos según el tipo de pago
                        if paymentType == .automatic {
                            transaction.automaticPaymentOption = automaticPaymentOption
                            
                            // Para opción de día específico, guardar el día del mes
                            if automaticPaymentOption == .specificDay {
                                transaction.paymentDay = paymentDay
                            }
                            
                            // Para opción de día de la semana, guardar el día
                            if automaticPaymentOption == .specificWeekDay {
                                transaction.weekDay = specificWeekDay
                            }
                        }
                        
                        // Configurar fecha de fin si está habilitada
                        if hasEndDate {
                            if endDateType == .specific {
                                transaction.endDate = endDate
                            } else {
                                // Calcular la fecha de fin según la duración
                                let calendar = Calendar.current
                                if durationType == .months {
                                    transaction.endDate = calendar.date(byAdding: .month, value: durationValue, to: startDate)
                                } else {
                                    transaction.endDate = calendar.date(byAdding: .year, value: durationValue, to: startDate)
                                }
                            }
                        }
                        
                        // Extraer el día del mes de la fecha de inicio
                        if let startDate = transaction.startDate {
                            let calendar = Calendar.current
                            let dayComponents = calendar.dateComponents([.day], from: startDate)
                            transaction.paymentDay = dayComponents.day
                        }
                        
                        // Añadir la transacción
                        viewModel.addTransaction(transaction)
                        
                        // Forzar una actualización adicional de la interfaz
                        DispatchQueue.main.async {
                            viewModel.refreshTotals()
                        }
                        
                        // Actualizar datos del widget
                        WidgetDataProvider.shared.updateWidgetData()
                        
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
            .onAppear {
                // Asegurar que se carguen los métodos de pago actualizados
                viewModel.reloadCustomPaymentMethods()
                // Asegurar que se carguen las categorías actualizadas
                viewModel.reloadCustomCategories()
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePicker("Selecciona fecha de inicio",
                          selection: $startDate,
                          displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .presentationDetents([.medium])
                    .environment(\.locale, Locale(identifier: "es_ES"))
            }
            .sheet(isPresented: $showingEndDatePicker) {
                DatePicker("Selecciona fecha de finalización",
                          selection: $endDate,
                          displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .presentationDetents([.medium])
                    .environment(\.locale, Locale(identifier: "es_ES"))
            }
        }
    }
}

struct TransactionSettingsView: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPaymentMethod: PaymentMethod
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String
    @State private var isAutomaticPayment: Bool
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedPaymentMethod = State(initialValue: transaction.paymentMethod)
        _customPaymentMethod = State(initialValue: transaction.customPaymentMethod)
        _isAutomaticPayment = State(initialValue: transaction.paymentType == .automatic)
        
        // Inicializar el string del método de pago (estándar o personalizado)
        if transaction.paymentMethod == .custom, let customMethod = transaction.customPaymentMethod {
            _selectedPaymentMethodString = State(initialValue: customMethod)
        } else {
            _selectedPaymentMethodString = State(initialValue: transaction.paymentMethod.rawValue)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Método de pago")) {
                    Picker("Método", selection: $selectedPaymentMethodString) {
                        ForEach(viewModel.getAllPaymentMethods(), id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .onChange(of: selectedPaymentMethodString) { newValue in
                        // Buscar si coincide con algún método estándar
                        if let standardMethod = PaymentMethod.allCases.first(where: { $0.rawValue == newValue }) {
                            selectedPaymentMethod = standardMethod
                            customPaymentMethod = nil
                        } else {
                            // Es un método personalizado
                            selectedPaymentMethod = .custom
                            customPaymentMethod = newValue
                        }
                    }
                }
                
                Section(header: Text("Programación de pago")) {
                    Toggle("Pago automático", isOn: $isAutomaticPayment)
                    
                    if isAutomaticPayment {
                        Text("El pago se realizará el día \(transaction.paymentDay ?? 1) de cada mes, según la fecha de inicio configurada.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        var updatedTransaction = transaction
                        updatedTransaction.paymentMethod = selectedPaymentMethod
                        updatedTransaction.customPaymentMethod = customPaymentMethod
                        updatedTransaction.paymentType = isAutomaticPayment ? .automatic : .manual
                        
                        // El día de pago se mantiene según la fecha de inicio
                        if isAutomaticPayment {
                            // Si no hay paymentDay establecido, extraerlo de la fecha de inicio
                            if updatedTransaction.paymentDay == nil && updatedTransaction.startDate != nil {
                                let calendar = Calendar.current
                                let dayComponents = calendar.dateComponents([.day], from: updatedTransaction.startDate!)
                                updatedTransaction.paymentDay = dayComponents.day
                            }
                            updatedTransaction.automaticPaymentOption = .specificDay
                        } else {
                            updatedTransaction.paymentDay = nil
                            updatedTransaction.automaticPaymentOption = nil
                        }
                        
                        viewModel.deleteTransaction(transaction)
                        
                        // Forzar una actualización adicional de la interfaz
                        DispatchQueue.main.async {
                            viewModel.refreshTotals()
                        }
                        
                        // Actualizar datos del widget
                        WidgetDataProvider.shared.updateWidgetData()
                        
                        viewModel.addTransaction(updatedTransaction)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
