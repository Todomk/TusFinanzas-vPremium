import SwiftUI

// Extensión para replegar el teclado al tocar fuera de un campo de texto
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct QuickGPEntryView: View {
    @Binding var isPresented: Bool
    let initialAmount: Double
    let initialCategory: GPCategory
    @State private var isQuickAmountEntry: Bool
    @ObservedObject var viewModel: FinanceViewModel
    
    @State private var amount: String = ""
    @State private var concept: String = ""
    @State private var category: GPCategory
    @State private var customGPCategory: String?
    @State private var selectedCategoryString: String
    @State private var paymentMethod: PaymentMethod
    @State private var customPaymentMethod: String?
    @State private var selectedPaymentMethodString: String = ""
    @State private var date: Date = Date()
    @State private var showingSuccessMessage = false
    
    init(isPresented: Binding<Bool>, initialAmount: Double, initialCategory: GPCategory, initialPaymentMethod: PaymentMethod = .cash, isQuickAmountEntry: Bool, viewModel: FinanceViewModel) {
        self._isPresented = isPresented
        self.initialAmount = initialAmount
        self.initialCategory = initialCategory
        self._isQuickAmountEntry = State(initialValue: isQuickAmountEntry)
        self.viewModel = viewModel
        
        // Inicializar valores predeterminados
        self._category = State(initialValue: initialCategory)
        self._customGPCategory = State(initialValue: nil)
        
        // Inicializar selectedCategoryString con el valor de la categoría inicial
        self._selectedCategoryString = State(initialValue: initialCategory.rawValue)
        
        self._paymentMethod = State(initialValue: initialPaymentMethod)
        
        // Inicializar selectedPaymentMethodString con el valor del método de pago
        self._selectedPaymentMethodString = State(initialValue: initialPaymentMethod.rawValue)
        
        // Predeterminar un concepto basado en la categoría
        var defaultConcept = ""
        switch initialCategory {
        case .restauracion:
            defaultConcept = "Comida"
        case .gasolina:
            defaultConcept = "Repostaje"
        case .supermercados:
            defaultConcept = "Compra"
        default:
            defaultConcept = initialCategory.rawValue.capitalized
        }
        self._concept = State(initialValue: defaultConcept)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fondo de pantalla completa negro
                Color.black
                    .ignoresSafeArea()
                
                // Contenido principal con fondo de sistema
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .padding(.bottom, getSafeAreaBottom())
                    .onTapGesture {
                        // Cerrar el teclado al tocar el fondo
                        UIApplication.shared.endEditing()
                    }
                
                VStack(spacing: 0) {
                    // Cabecera con título y categoría
                    VStack(spacing: 0) {
                        // Título y botón de cerrar
                        HStack {
                            Spacer()
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.trailing, 10)
                        }
                        .padding(.top, geometry.safeAreaInsets.top + 15)
                        .padding(.bottom, 10)
                        
                        // Indicador de categoría y cantidad (si es rápida)
                        VStack(spacing: 5) {
                            HStack(spacing: 8) {
                                Image(systemName: iconForCategory(category))
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                
                                Text(category.rawValue.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            if isQuickAmountEntry {
                                Text("\(Int(initialAmount))€")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 15)
                    }
                    .background(colorForCategory(category))
                    
                    if showingSuccessMessage {
                        successMessageView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        formView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .onAppear {
                // Asegurar que se carguen los métodos de pago actualizados
                viewModel.reloadCustomPaymentMethods()
                // Asegurar que se carguen las categorías actualizadas
                viewModel.reloadCustomCategories()
                
                // Si es una entrada rápida, guardar automáticamente después de un breve retraso
                if isQuickAmountEntry {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        saveTransactionAndShowSuccess()
                    }
                }
            }
        }
    }
    
    var formView: some View {
        VStack(spacing: 0) {
            // Título de la vista
            Text("Nuevo gasto diario")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, 24)
                .shadow(color: Color.black.opacity(0.05), radius: 0.5, x: 0, y: 0.5)
                
            // Formulario
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Campos en layout horizontal compacto
                    // Campo de cantidad
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "eurosign.circle.fill")
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 1, x: 0, y: 0)
                            
                            Text("Cantidad")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 95, alignment: .leading)
                        .padding(.leading, 4)
                        
                        TextField("0,00", text: $amount)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                            )
                        
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 2)
                    }
                    .padding(.vertical, 3)
                    
                    // Campo de concepto
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "text.append")
                                .foregroundColor(.purple)
                                .shadow(color: .purple.opacity(0.3), radius: 1, x: 0, y: 0)
                            
                            Text("Concepto")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 95, alignment: .leading)
                        .padding(.leading, 4)
                        
                        TextField("Descripción", text: $concept)
                            .padding(.horizontal)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                            )
                        
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 2)
                    }
                    .padding(.vertical, 3)
                    
                    // Selector de categoría
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                                .shadow(color: .orange.opacity(0.3), radius: 1, x: 0, y: 0)
                            
                            Text("Categoría")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 95, alignment: .leading)
                        .padding(.leading, 4)
                        
                        Picker("", selection: $selectedCategoryString) {
                            ForEach(viewModel.getAllCategories(), id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        )
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
                    }
                    .padding(.vertical, 3)
                    
                    // Selector de método de pago
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.green)
                                .shadow(color: .green.opacity(0.3), radius: 1, x: 0, y: 0)
                            
                            Text("Método")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 95, alignment: .leading)
                        .padding(.leading, 4)
                        
                        Picker("", selection: $selectedPaymentMethodString) {
                            ForEach(viewModel.getAllPaymentMethods(), id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        )
                    }
                    .padding(.vertical, 3)
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
                    
                    // Fecha y hora en formato horizontal
                    HStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.red)
                                .shadow(color: .red.opacity(0.3), radius: 1, x: 0, y: 0)
                            
                            Text("Fecha/Hora")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
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
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
            
            // Botones de acción
            HStack(spacing: 10) {
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
                                    colorForCategory(category),
                                    colorForCategory(category).opacity(0.85)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: colorForCategory(category).opacity(0.3), radius: 2, x: 0, y: 1)
                }
                
                Button(action: {
                    // Cerrar teclado antes de cancelar
                    UIApplication.shared.endEditing()
                    withAnimation {
                        isPresented = false
                    }
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 15)
            .padding(.bottom, getSafeAreaBottom())
        }
    }
    
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
                
                Text("\(concept)")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForCategory(category))
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
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
            .padding(.bottom, getSafeAreaBottom())
        }
    }
    
    // Función para obtener el safe area bottom
    func getSafeAreaBottom() -> CGFloat {
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
    
    // Función para guardar la transacción y mostrar mensaje de éxito
    private func saveTransactionAndShowSuccess() {
        saveTransaction()
        withAnimation {
            showingSuccessMessage = true
        }
        
        // Cerrar automáticamente después de 2 segundos si fue entrada rápida
        // o después de 3 segundos si fue entrada manual
        let delay = isQuickAmountEntry ? 1.5 : 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation {
                isPresented = false
            }
        }
    }
    
    private func saveTransaction() {
        // Formato de texto para fecha/hora con Locale español
        // Guardar la transacción
        let newTransaction = Transaction(
            amount: Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0,
            concept: concept.isEmpty ? "Gasto \(selectedCategoryString)" : concept,
            isCompleted: true,
            type: .gp,
            periodicity: .monthly,
            paymentType: .manual,
            paymentMethod: paymentMethod,
            customPaymentMethod: customPaymentMethod,
            startDate: date,
            gpCategory: category,
            customGPCategory: customGPCategory
        )
        
        viewModel.addTransaction(newTransaction)
        
        // Actualizar los datos del widget
        WidgetDataProvider.shared.updateWidgetData()
        
        print("QuickGPEntryView: Transacción guardada - \(concept): \(amount)€")
    }
    
    // Función auxiliar para formatear moneda
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: amount)) ?? "€0,00"
    }
    
    // Función para obtener el icono de la categoría
    private func iconForCategory(_ category: GPCategory) -> String {
        switch category {
        case .restauracion:
            return "fork.knife"
        case .gasolina:
            return "fuelpump.fill"
        case .supermercados:
            return "cart.fill"
        case .ropa:
            return "tshirt.fill"
        case .compraOnline:
            return "bag.fill"
        case .salud:
            return "heart.fill"
        case .belleza:
            return "scissors"
        case .ocio:
            return "gamecontroller.fill"
        case .otros:
            return "ellipsis.circle.fill"
        }
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
} 