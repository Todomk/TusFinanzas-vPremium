import SwiftUI

struct EditTransactionView: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String
    @State private var concept: String
    @State private var periodicity: Periodicity
    @State private var paymentType: PaymentType
    @State private var paymentMethod: PaymentMethod
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String
    @State private var startDate: Date
    @State private var showingDeleteConfirmation = false
    @State private var showingDatePicker = false
    
    // Nuevos campos para gestionar el fin del pago
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showingEndDatePicker = false
    @State private var endDateType: EndDateType = .duration
    @State private var durationValue: Int = 12
    @State private var durationType: DurationType = .months
    @State private var showPeriodicityAlert = false
    
    // Enumeraciones para los tipos de fin de pago
    enum EndDateType: String, CaseIterable {
        case specific = "Fecha específica"
        case duration = "Duración"
    }
    
    enum DurationType: String, CaseIterable {
        case months = "Meses"
        case years = "Años"
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _amount = State(initialValue: String(transaction.amount))
        _concept = State(initialValue: transaction.concept)
        _periodicity = State(initialValue: transaction.periodicity)
        _paymentType = State(initialValue: transaction.paymentType)
        _paymentMethod = State(initialValue: transaction.paymentMethod)
        _customPaymentMethod = State(initialValue: transaction.customPaymentMethod)
        _startDate = State(initialValue: transaction.startDate ?? Date())
        
        // Inicializar el string del método de pago (estándar o personalizado)
        if transaction.paymentMethod == .bank, let customMethod = transaction.customPaymentMethod {
            _selectedPaymentMethodString = State(initialValue: customMethod)
        } else {
            _selectedPaymentMethodString = State(initialValue: transaction.paymentMethod.rawValue)
        }
        
        // Inicialización de la fecha de fin
        _hasEndDate = State(initialValue: transaction.endDate != nil)
        _endDate = State(initialValue: transaction.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: transaction.startDate ?? Date()) ?? Date())
        
        // Determinar tipo de fin de fecha y duración si corresponde
        if let startDate = transaction.startDate, let endDate = transaction.endDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.month, .year], from: startDate, to: endDate)
            
            if let months = components.month, let years = components.year {
                let totalMonths = months + (years * 12)
                
                if totalMonths % 12 == 0 && totalMonths > 0 {
                    // Si es múltiplo de 12, usar años
                    _durationValue = State(initialValue: totalMonths / 12)
                    _durationType = State(initialValue: .years)
                } else {
                    // De lo contrario, usar meses
                    _durationValue = State(initialValue: totalMonths)
                    _durationType = State(initialValue: .months)
                }
            }
        }
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
                // Título de la vista
                Section {
                    Text("Editar transacción")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 5)
                }
                
                Section(header: Text("Información básica")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Concepto")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Concepto", text: $concept)
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cantidad")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                }
                
                Section(header: Text("Configuración")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Periodicidad")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: Binding(
                            get: { periodicity },
                            set: { newValue in
                                // Si cambia a una periodicidad no mensual y tiene fecha de finalización
                                if newValue != .monthly && hasEndDate {
                                    showPeriodicityAlert = true
                                    hasEndDate = false
                                }
                                periodicity = newValue
                            }
                        )) {
                            // Solo mostrar las periodicidades adecuadas según el tipo de transacción
                            if transaction.type == .expense {
                                // Para gastos, mostrar solo las periodicidades específicas
                                ForEach(Periodicity.expensePeriodicities, id: \.self) { period in
                                    Text(period.rawValue).tag(period)
                                }
                            } else {
                                // Para otros tipos de transacción, mostrar todas las opciones
                                ForEach(Periodicity.allCases, id: \.self) { period in
                                    Text(period.rawValue).tag(period)
                                }
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Tipo de pago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $paymentType) {
                            ForEach(PaymentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Método de pago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $selectedPaymentMethodString) {
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
                                paymentMethod = .bank
                                customPaymentMethod = newValue
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(transaction.type == .income ? "Fecha de ingreso" : "Fecha de inicio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: { showingDatePicker = true }) {
                            HStack {
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Sección para la fecha de finalización (para todos los tipos)
                Section(header: Text("Finalización")) {
                    Toggle("Tiene fecha de finalización", isOn: Binding(
                        get: { hasEndDate },
                        set: { newValue in
                            if newValue && periodicity != .monthly {
                                showPeriodicityAlert = true
                            } else {
                                hasEndDate = newValue
                            }
                        }
                    ))
                    
                    if hasEndDate {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Tipo de finalización")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $endDateType) {
                                ForEach(EndDateType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }
                        
                        if endDateType == .specific {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Fecha de finalización")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(action: { showingEndDatePicker = true }) {
                                    HStack {
                                        Text(endDate.formatted(date: .abbreviated, time: .omitted))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        } else {
                            // Duración en meses o años
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Duración")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Stepper(value: $durationValue, in: 1...60) {
                                    Text(formatDuration())
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Unidad")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $durationType) {
                                    ForEach(DurationType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .labelsHidden()
                            }
                            
                            // Mostrar la fecha calculada
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Fecha de finalización calculada")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(calculateEndDate().formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section {
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Eliminar transacción")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Guardar") {
                    if let amount = Double(amount),
                       !concept.isEmpty {
                        // Validar que si tiene fecha de finalización, la periodicidad sea mensual
                        if hasEndDate && periodicity != .monthly {
                            showPeriodicityAlert = true
                            return
                        }
                        
                        // Para gastos, verificar que la periodicidad sea una de las permitidas
                        if transaction.type == .expense && !periodicity.isValidForExpense {
                            // Si no es válida, forzar a mensual
                            periodicity = .monthly
                        }
                        
                        var updatedTransaction = transaction
                        updatedTransaction.amount = amount
                        updatedTransaction.concept = concept
                        updatedTransaction.periodicity = periodicity
                        updatedTransaction.paymentType = paymentType
                        updatedTransaction.paymentMethod = paymentMethod
                        updatedTransaction.customPaymentMethod = customPaymentMethod
                        updatedTransaction.startDate = startDate
                        
                        // Configurar la fecha de fin si está habilitada
                        if hasEndDate {
                            if endDateType == .specific {
                                updatedTransaction.endDate = endDate
                            } else {
                                updatedTransaction.endDate = calculateEndDate()
                            }
                        } else {
                            updatedTransaction.endDate = nil
                        }
                        
                        // Forzar el recálculo de la próxima fecha de aparición
                        if let startDate = updatedTransaction.startDate {
                            // Extraer el día del mes de la fecha de inicio
                            let calendar = Calendar.current
                            let dayComponents = calendar.dateComponents([.day], from: startDate)
                            updatedTransaction.paymentDay = dayComponents.day
                            
                            // Eliminar configuraciones antiguas que ya no usamos
                            updatedTransaction.automaticPaymentOption = nil
                            updatedTransaction.weekDay = nil
                            
                            // Calcular los meses de aparición según la nueva periodicidad
                            updatedTransaction.appearanceMonths = Transaction.calculateAppearanceMonths(
                                startDate: startDate,
                                endDate: updatedTransaction.endDate,
                                periodicity: updatedTransaction.periodicity
                            )
                            
                            // Calcular la próxima fecha de aparición basada en los meses calculados
                            if startDate > Date() {
                                // Si la fecha de inicio es futura, la próxima aparición es la fecha de inicio
                                updatedTransaction.nextAppearanceDate = startDate
                            } else {
                                // Usar determineNextAppearanceDate (método del ViewModel)
                                // Como estamos en la vista y no podemos acceder directamente al método privado
                                // del ViewModel, calculamos la próxima aparición con el método estático
                                updatedTransaction.nextAppearanceDate = Transaction.calculateNextAppearanceDate(
                                    startDate: startDate,
                                    lastResetDate: updatedTransaction.lastResetDate,
                                    periodicity: updatedTransaction.periodicity
                                )
                            }
                            
                            // Imprimir información de depuración
                            if let nextDate = updatedTransaction.nextAppearanceDate {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd/MM/yyyy"
                                print("EditTransactionView: Próxima aparición calculada: \(formatter.string(from: nextDate))")
                            }
                        }
                        
                        viewModel.deleteTransaction(transaction)
                        viewModel.addTransaction(updatedTransaction)
                        
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
            .alert("¿Estás seguro?", isPresented: $showingDeleteConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    viewModel.deleteTransaction(transaction)
                    
                    // Forzar una actualización adicional de la interfaz
                    DispatchQueue.main.async {
                        viewModel.refreshTotals()
                    }
                    
                    // Actualizar datos del widget
                    WidgetDataProvider.shared.updateWidgetData()
                    
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("¿Quieres eliminar esta transacción?")
            }
            .alert("Error de periodicidad", isPresented: $showPeriodicityAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("La periodicidad debe ser mensual para poder establecer una fecha de finalización. Las transacciones con periodicidad no mensual como trimestral, semestral, etc. no pueden tener una fecha de finalización definida.")
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
            .onAppear {
                // Asegurar que se carguen los métodos de pago actualizados
                viewModel.reloadCustomPaymentMethods()
            }
        }
    }
} 