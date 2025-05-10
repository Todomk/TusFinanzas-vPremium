import SwiftUI

struct AddGPTransactionView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    
    // Nuevo parámetro opcional para manejar el caso de presentación normal
    var externalIsPresented: Binding<Bool>?
    
    @State private var amount: String = "0.00"
    @State private var concept: String = ""
    @State private var category: GPCategory = .otros
    @State private var customGPCategory: String?
    @State private var selectedCategoryString: String = "Otros"
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String = "Efectivo"
    @State private var date: Date = Date()
    @State private var isProcessingQuickEntry: Bool = false
    @State private var showingSuccessMessage: Bool = false
    @State private var showInvalidDateAlert: Bool = false
    
    // Para almacenar temporalmente los datos precargados
    private var prefilledAmount: Double {
        deepLinkHandler.prefilledAmount
    }
    
    private var prefilledCategory: GPCategory {
        deepLinkHandler.prefilledCategory
    }
    
    private var shouldAutoSave: Bool {
        deepLinkHandler.shouldAutoSave
    }
    
    private var isFullScreenMode: Bool {
        deepLinkHandler.showFullScreenMode
    }
    
    var body: some View {
        ZStack {
            // Fondo negro cuando se muestra a pantalla completa
            if isFullScreenMode {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Cerrar el teclado al tocar el fondo
                        UIApplication.shared.endEditing()
                    }
            }
            
            if showingSuccessMessage {
                successMessageView
            } else {
                VStack {
                    // Barra de navegación personalizada para modo pantalla completa
                    if isFullScreenMode {
                        HStack {
                            Spacer()
                            Spacer()
                        }
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        
                        Divider()
                    }
                    
                    // Contenido del formulario
                    if isFullScreenMode {
                        // Versión personalizada para pantalla completa
                        fullScreenForm
                    } else {
                        // Versión original con NavigationView
                        standardForm
                    }
                }
                .background(isFullScreenMode ? Color(.systemBackground) : Color.clear)
                .cornerRadius(isFullScreenMode ? 15 : 0)
                .padding(.vertical, isFullScreenMode ? 10 : 0)
                .padding(.horizontal, isFullScreenMode ? 0 : 0)
            }
        }
        .onAppear {
            setupPrefilledData()
        }
        .alert("Fecha no válida", isPresented: $showInvalidDateAlert) {
            Button("Aceptar", role: .cancel) { }
        } message: {
            Text("No se pueden insertar nuevos gastos con fechas anteriores al mes actual")
        }
    }
    
    // Vista normal dentro de NavigationView
    var standardForm: some View {
        NavigationView {
            Form {
                formContent
            }
            .contentShape(Rectangle()) // Hacer toda el área táctil
            .onTapGesture {
                // Cerrar el teclado al tocar el fondo
                UIApplication.shared.endEditing()
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    // Cerrar teclado antes de cancelar
                    UIApplication.shared.endEditing()
                    dismissView()
                },
                trailing: Button("Guardar") {
                    // Cerrar teclado antes de guardar
                    UIApplication.shared.endEditing()
                    saveTransactionAndShowSuccess()
                }
                .disabled(amount.isEmpty || concept.isEmpty)
            )
        }
    }
    
    // Función para cerrar la vista correctamente
    private func dismissView() {
        // Si tenemos un binding externo, usarlo
        if let externalBinding = externalIsPresented {
            withAnimation {
                externalBinding.wrappedValue = false
            }
        } else {
            // Si no, usar el deepLinkHandler
            withAnimation {
                deepLinkHandler.showAddGPView = false
            }
        }
        
        // También usar presentationMode como respaldo
        presentationMode.wrappedValue.dismiss()
    }
    
    // Vista a pantalla completa con estilo personalizado
    var fullScreenForm: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Título de la vista
            Text("Nuevo gasto diario")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .shadow(color: Color.black.opacity(0.05), radius: 0.5, x: 0, y: 0.5)
            
            // Contenido principal en una sola pantalla
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Información básica en layout más compacto
                    Group {
                        // Campo de concepto
                        HStack(alignment: .center) {
                            Text("Concepto")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .frame(width: 95, alignment: .leading)
                                .padding(.leading, 4)
                            
                            TextField("Concepto", text: $concept)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.clear)
                                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                )
                            
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 4)
                        }
                        .padding(.vertical, 3)
                        
                        // Campo de cantidad
                        HStack(alignment: .center) {
                            Text("Cantidad")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .frame(width: 95, alignment: .leading)
                                .padding(.leading, 4)
                            
                            TextField("Cantidad", text: $amount)
                                .keyboardType(.decimalPad)
                                .onChange(of: amount) { formatAmount($0) }
                            Text("€")
                                .foregroundColor(.secondary)
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                        
                        // Selector de categoría
                        HStack(alignment: .center) {
                            Text("Categoría")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .frame(width: 95, alignment: .leading)
                                .padding(.leading, 4)
                            
                            Picker("", selection: $selectedCategoryString) {
                                ForEach(viewModel.getAllCategories(), id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .onChange(of: selectedCategoryString) { newValue in
                                // Buscar si coincide con alguna categoría estándar
                                if let standardCategory = GPCategory.allCases.first(where: { $0.rawValue == newValue }) {
                                    category = standardCategory
                                    customGPCategory = nil
                                    print("Categoría estándar seleccionada: \(newValue)")
                                } else {
                                    // Es una categoría personalizada
                                    category = .otros // Usar categoría por defecto como respaldo
                                    customGPCategory = newValue
                                    print("Categoría personalizada seleccionada: \(newValue)")
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }
                        .padding(.vertical, 3)
                        
                        // Primer picker de método de pago (en formulario emergente)
                        HStack(alignment: .center) {
                            Text("Método pago")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .frame(width: 95, alignment: .leading)
                                .padding(.leading, 4)
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
                                    print("Método de pago estándar seleccionado: \(newValue)")
                                } else {
                                    // Es un método personalizado
                                    paymentMethod = .bank // Usar un método default como respaldo
                                    customPaymentMethod = newValue
                                    print("Método de pago personalizado seleccionado: \(newValue)")
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }.padding(.vertical, 2)
                        
                        // Fecha y hora en formato vertical
                        HStack(alignment: .center, spacing: 4) {
                            Text("Fecha/Hora")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .frame(width: 95, alignment: .leading)
                                .padding(.leading, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                // Fecha
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .environment(\.locale, Locale(identifier: "es_ES"))
                                    .labelsHidden()
                                    .fixedSize()
                                    .padding(.horizontal, 5)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                    )
                                
                                // Hora
                                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                                    .environment(\.locale, Locale(identifier: "es_ES"))
                                    .labelsHidden()
                                    .fixedSize()
                                    .padding(.horizontal, 5)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                    )
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 4)
            }
            
            // Botones de acción compactos
            HStack(spacing: 10) {
                // Botón cancelar
                Button(action: {
                    // Cerrar teclado antes de cancelar
                    UIApplication.shared.endEditing()
                    dismissView()
                }) {
                    Text("Cancelar")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                // Botón guardar
                Button(action: {
                    // Cerrar teclado antes de guardar
                    UIApplication.shared.endEditing()
                    saveTransactionAndShowSuccess()
                }) {
                    Text("Guardar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.85)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
                        .opacity(amount.isEmpty || concept.isEmpty ? 0.6 : 1.0)
                }
                .disabled(amount.isEmpty || concept.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // Cerrar el teclado al tocar el fondo
            UIApplication.shared.endEditing()
        }
    }
    
    // Vista de mensaje de éxito
    var successMessageView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 10) {
                Text("¡Gasto añadido!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(concept.isEmpty ? "Gasto sin concepto" : concept)")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForCategory(category))
            }
            
            Spacer()
            
            Button(action: {
                dismissView()
            }) {
                Text("Cerrar")
                    .fontWeight(.semibold)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(isFullScreenMode ? 15 : 0)
    }
    
    // Contenido común del formulario para la versión estándar
    var formContent: some View {
        Group {
            // Título de la vista como título estándar sin fondo
            Text("Nuevo gasto diario")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 3, leading: 20, bottom: 0, trailing: 16))
                .shadow(color: Color.black.opacity(0.05), radius: 0.5, x: 0, y: 0.5)
            
            // Sección única ultracompacta
            Section {
                Group {
                    // Concepto
                    HStack(alignment: .center) {
                        Text("Concepto")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 95, alignment: .leading)
                            .padding(.leading, 4)
                        
                        TextField("Concepto", text: $concept)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.clear)
                                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                            )
                        
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 2)
                    
                    // Cantidad
                    HStack(alignment: .center) {
                        Text("Cantidad")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 95, alignment: .leading)
                            .padding(.leading, 4)
                        TextField("Cantidad", text: $amount)
                            .keyboardType(.decimalPad)
                            .onChange(of: amount) { formatAmount($0) }
                        Text("€")
                            .foregroundColor(.secondary)
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                    }.padding(.vertical, 2)
                
                    // Categoría
                    HStack(alignment: .center) {
                        Text("Categoría")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 95, alignment: .leading)
                            .padding(.leading, 4)
                        Picker("", selection: $selectedCategoryString) {
                            ForEach(viewModel.getAllCategories(), id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .onChange(of: selectedCategoryString) { newValue in
                            // Buscar si coincide con alguna categoría estándar
                            if let standardCategory = GPCategory.allCases.first(where: { $0.rawValue == newValue }) {
                                category = standardCategory
                                customGPCategory = nil
                                print("Categoría estándar seleccionada: \(newValue)")
                            } else {
                                // Es una categoría personalizada
                                category = .otros // Usar categoría por defecto como respaldo
                                customGPCategory = newValue
                                print("Categoría personalizada seleccionada: \(newValue)")
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }.padding(.vertical, 2)
                    
                    // Segundo picker de método de pago (en vista completa)
                    HStack(alignment: .center) {
                        Text("Método pago")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 95, alignment: .leading)
                            .padding(.leading, 4)
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
                                print("Método de pago estándar seleccionado: \(newValue)")
                            } else {
                                // Es un método personalizado
                                paymentMethod = .bank // Usar un método default como respaldo
                                customPaymentMethod = newValue
                                print("Método de pago personalizado seleccionado: \(newValue)")
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }.padding(.vertical, 2)
                    
                    // Fecha y hora en formato vertical
                    HStack(alignment: .center, spacing: 4) {
                        Text("Fecha/Hora")
                            .font(.callout)
                            .foregroundColor(.primary)
                            .frame(width: 95, alignment: .leading)
                            .padding(.leading, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // Fecha
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "es_ES"))
                                .labelsHidden()
                                .fixedSize()
                            
                            // Hora
                            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                                .environment(\.locale, Locale(identifier: "es_ES"))
                                .labelsHidden()
                                .fixedSize()
                        }
                    }.padding(.vertical, 2)
                }
            }
        }
    }
    
    // Función para formatear el campo de cantidad
    func formatAmount(_ newValue: String) {
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
    
    // Función para formatear moneda
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: amount)) ?? "€0,00"
    }
    
    // Función para obtener el color asociado a cada categoría
    private func colorForCategory(_ category: GPCategory) -> Color {
        switch category {
        case .restauracion:
            return Color.orange
        case .gasolina:
            return Color.red
        case .supermercados:
            return Color.green
        case .ropa:
            return Color.purple
        case .compraOnline:
            return Color.blue
        case .salud:
            return Color.pink
        case .belleza:
            return Color.teal
        case .ocio:
            return Color.indigo
        case .otros:
            return Color.gray
        }
    }
    
    // Función para guardar la transacción y mostrar mensaje de éxito
    func saveTransactionAndShowSuccess() {
        saveTransaction()
        
        // Mostrar mensaje de éxito
        withAnimation {
            showingSuccessMessage = true
        }
        
        // Cerrar automáticamente después de un tiempo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                dismissView()
            }
        }
    }
    
    // Función para guardar la transacción
    func saveTransaction() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        // Validar que la fecha no sea anterior al mes actual
        let calendar = Calendar.current
        let now = Date()
        
        // Obtener componentes de año y mes de ambas fechas
        let dateComponents = calendar.dateComponents([.year, .month], from: date)
        let currentComponents = calendar.dateComponents([.year, .month], from: now)
        
        // Comprobar si la fecha es anterior al mes actual
        let isBeforeCurrentMonth = dateComponents.year! < currentComponents.year! || 
                                  (dateComponents.year! == currentComponents.year! && 
                                   dateComponents.month! < currentComponents.month!)
        
        if isBeforeCurrentMonth {
            showInvalidDateAlert = true
            return
        }
        
        let newTransaction = Transaction(
            amount: amountValue,
            concept: concept.isEmpty ? "Gasto \(selectedCategoryString)" : concept,
            isCompleted: true,
            type: .gp,
            periodicity: .monthly,
            paymentType: .manual,
            paymentMethod: paymentMethod,
            paymentDay: nil,
            weekDay: nil,
            automaticPaymentOption: nil,
            startDate: date,
            endDate: nil,
            lastResetDate: nil,
            weeklyAmounts: nil,
            gpCategory: category,
            nextAppearanceDate: nil,
            customPaymentMethod: customPaymentMethod,
            customGPCategory: customGPCategory
        )
        
        // Log para depuración
        print("SaveTransaction: Creando gasto diario")
        print("- Método de pago: \(paymentMethod.rawValue)")
        print("- Método personalizado: \(customPaymentMethod ?? "N/A")")
        print("- Categoría: \(category.rawValue)")
        print("- Categoría personalizada: \(customGPCategory ?? "N/A")")
        
        // Guardar transacción
        viewModel.addTransaction(newTransaction)
        
        // Forzar una actualización adicional de la interfaz
        DispatchQueue.main.async {
            viewModel.refreshTotals()
        }
        
        // También actualizar los datos del widget
        WidgetDataProvider.shared.updateWidgetData()
        
        print("AddGPTransactionView: Transacción guardada - \(concept): \(amountValue)€")
    }
    
    // Preparar los datos precargados
    private func setupPrefilledData() {
        print("AddGPTransactionView: Configurando datos precargados")
        print("- Cantidad: \(prefilledAmount)")
        print("- Categoría: \(prefilledCategory.rawValue)")
        print("- Categoría personalizada: \(deepLinkHandler.prefilledCustomCategory ?? "N/A")")
        print("- Método de pago personalizado: \(deepLinkHandler.prefilledCustomPaymentMethod ?? "N/A")")
        print("- AutoSave: \(shouldAutoSave)")
        print("- FullScreen: \(isFullScreenMode)")
        
        // Asegurar que se carguen los métodos de pago actualizados
        viewModel.reloadCustomPaymentMethods()
        // Asegurar que se carguen las categorías actualizadas
        viewModel.reloadCustomCategories()
        
        // Cargar los valores preestablecidos
        if prefilledAmount > 0 {
            amount = String(format: "%.2f", prefilledAmount)
        }
        
        // No modificar el concepto, dejarlo vacío como valor por defecto
        
        // Configurar categoría (estándar o personalizada)
        if deepLinkHandler.isQuickAmountEntry || prefilledCategory != .otros {
            // Si es una categoría personalizada, configurarla correctamente
            if let customCat = deepLinkHandler.prefilledCustomCategory {
                category = .otros
                customGPCategory = customCat
                selectedCategoryString = customCat
                print("Configurando categoría personalizada: \(customCat)")
            } else {
                // Si es una categoría estándar
                category = prefilledCategory
                customGPCategory = nil
                selectedCategoryString = prefilledCategory.rawValue
                print("Configurando categoría estándar: \(prefilledCategory.rawValue)")
            }
        }
        
        // Configurar método de pago (estándar o personalizado)
        if let customMethod = deepLinkHandler.prefilledCustomPaymentMethod {
            paymentMethod = .bank
            customPaymentMethod = customMethod
            selectedPaymentMethodString = customMethod
            print("Configurando método de pago personalizado: \(customMethod)")
        } else {
            paymentMethod = deepLinkHandler.prefilledPaymentMethod
            customPaymentMethod = nil
            selectedPaymentMethodString = deepLinkHandler.prefilledPaymentMethod.rawValue
            print("Configurando método de pago estándar: \(deepLinkHandler.prefilledPaymentMethod.rawValue)")
        }
        
        // Si debe autoguardar, hacerlo después de un breve retraso
        if shouldAutoSave && !isProcessingQuickEntry {
            isProcessingQuickEntry = true
            
            // Si está en modo pantalla completa no autoguardar, dejar que el usuario lo haga
            if !isFullScreenMode {
                // Si está activado el guardado automático y los datos son válidos, guardar después de un breve retraso
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !amount.isEmpty && !concept.isEmpty {
                        saveTransactionAndShowSuccess()
                    }
                }
            }
        }
    }
} 
