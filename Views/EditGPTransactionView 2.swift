import SwiftUI

struct EditGPTransactionView: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String
    @State private var concept: String
    @State private var paymentMethod: PaymentMethod
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String
    @State private var category: GPCategory
    @State private var customGPCategory: String?
    @State private var selectedCategoryString: String
    @State private var date: Date
    @State private var showingDeleteConfirmation = false
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _amount = State(initialValue: String(transaction.amount))
        _concept = State(initialValue: transaction.concept)
        _paymentMethod = State(initialValue: transaction.paymentMethod)
        _customPaymentMethod = State(initialValue: transaction.customPaymentMethod)
        _category = State(initialValue: transaction.gpCategory ?? .otros)
        _customGPCategory = State(initialValue: transaction.customGPCategory)
        _date = State(initialValue: transaction.startDate ?? Date())
        
        // Inicializar el string del método de pago (estándar o personalizado)
        if transaction.paymentMethod == .custom, let customMethod = transaction.customPaymentMethod {
            _selectedPaymentMethodString = State(initialValue: customMethod)
        } else {
            _selectedPaymentMethodString = State(initialValue: transaction.paymentMethod.rawValue)
        }
        
        // Inicializar el string de la categoría (estándar o personalizada)
        if let customCategory = transaction.customGPCategory {
            _selectedCategoryString = State(initialValue: customCategory)
        } else {
            _selectedCategoryString = State(initialValue: (transaction.gpCategory ?? .otros).rawValue)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Título de la vista
                Text("Editar gasto diario")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 0, trailing: 16))
                    .shadow(color: Color.black.opacity(0.05), radius: 0.5, x: 0, y: 0.5)
                
                // Sección única ultracompacta
                Section {
                    Group {
                        // Concepto
                        HStack(alignment: .center) {
                            Text("Concepto")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Concepto", text: $concept)
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .foregroundColor(.secondary)
                            }
                        }.padding(.vertical, 1)
                        
                        // Cantidad
                        HStack(alignment: .center) {
                            Text("Cantidad")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Cantidad", text: $amount)
                                .keyboardType(.decimalPad)
                                .onChange(of: amount) { newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    var formatted = filtered.replacingOccurrences(of: ",", with: ".")
                                    if formatted.components(separatedBy: ".").count > 2 {
                                        let components = formatted.components(separatedBy: ".")
                                        formatted = components.first! + "." + components.dropFirst().joined()
                                    }
                                    if let dotIndex = formatted.firstIndex(of: ".") {
                                        let decimalPart = formatted[formatted.index(after: dotIndex)...]
                                        if decimalPart.count > 2 {
                                            let endIndex = formatted.index(dotIndex, offsetBy: 3)
                                            formatted = String(formatted[..<endIndex])
                                        }
                                    }
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
                        }.padding(.vertical, 1)
                        
                        // Categoría
                        HStack(alignment: .center) {
                            Text("Categoría")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
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
                                } else {
                                    // Es una categoría personalizada - usar .otros como base y guardar el nombre personalizado
                                    category = .otros
                                    customGPCategory = newValue
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }.padding(.vertical, 1)
                        
                        // Método de pago
                        HStack(alignment: .center) {
                            Text("Método pago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
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
                                    paymentMethod = .custom
                                    customPaymentMethod = newValue
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }.padding(.vertical, 1)
                        
                        // Fecha
                        HStack(alignment: .center, spacing: 0) {
                            Text("Fecha/Hora")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
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
                        }.padding(.vertical, 1)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Botón eliminar
                Button(action: { showingDeleteConfirmation = true }) {
                    Text("Eliminar transacción")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Guardar") {
                    if let amount = Double(amount),
                       !concept.isEmpty {
                        var updatedTransaction = transaction
                        updatedTransaction.amount = amount
                        updatedTransaction.concept = concept
                        updatedTransaction.paymentMethod = paymentMethod
                        updatedTransaction.customPaymentMethod = customPaymentMethod
                        updatedTransaction.gpCategory = category
                        updatedTransaction.customGPCategory = customGPCategory
                        updatedTransaction.startDate = date
                        
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
            .onAppear {
                // Asegurar que se carguen los métodos de pago actualizados
                viewModel.reloadCustomPaymentMethods()
                // Asegurar que se carguen las categorías actualizadas
                viewModel.reloadCustomCategories()
            }
        }
    }
} 