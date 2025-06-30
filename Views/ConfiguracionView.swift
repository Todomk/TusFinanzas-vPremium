import SwiftUI
// Usando String.trimWhitespace() definido en StringExtensions.swift

struct ConfiguracionView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var selectedLanguage = "Español"
    @State private var featuresEnabled = true
    @State private var showingCreditosModal = false
    @State private var showingPaymentMethodsModal = false
    @State private var showingCategoriesModal = false
    @State private var showingResetConfirmation = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let languages = ["Español", "English"]
    
    // Inicializar el estado del toggle desde UserDefaults
    init() {
        _featuresEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "showTips"))
    }
    
    var body: some View {
        List {
            Section(header: Text("Preferencias")) {
                // Selector de idioma
                Picker("Idioma", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                
                // Toggles de activación
                Toggle("Mostrar propinas", isOn: $featuresEnabled)
                    .tint(.blue)
                    .onChange(of: featuresEnabled) { newValue in
                        // Guardar el nuevo valor en UserDefaults
                        UserDefaults.standard.set(newValue, forKey: "showTips")
                        // Notificar al ViewModel para que actualice los cálculos
                        viewModel.updateShowTipsPreference(newValue)
                    }
            }
            
            Section(header: Text("Personalización")) {
                // Botón para modificar métodos de pago
                Button {
                    showingPaymentMethodsModal = true
                } label: {
                    HStack {
                        Text("Métodos de pago")
                        Spacer()
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                // Botón para modificar categorías
                Button {
                    showingCategoriesModal = true
                } label: {
                    HStack {
                        Text("Categorías")
                        Spacer()
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section(header: Text("Mantenimiento")) {
                // Botón para limpiar archivos backup
                Button {
                    let result = viewModel.cleanBackupFiles()
                    if result.success {
                        alertMessage = result.message ?? "Archivos backup eliminados correctamente"
                    } else {
                        alertMessage = result.message ?? "Error al eliminar archivos backup"
                    }
                    showingAlert = true
                } label: {
                    HStack {
                        Text("Limpiar archivos backup")
                        Spacer()
                        Image(systemName: "trash.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section(header: Text("Información")) {
                // Botón para mostrar créditos
                Button {
                    showingCreditosModal = true
                } label: {
                    HStack {
                        Text("Créditos")
                        Spacer()
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Section {
                // Botón para restablecer valores
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("Restablecer valores y comenzar un nuevo ciclo")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Configuración")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Configuración")
                    .font(.title2)
                    .bold()
            }
        }
        .sheet(isPresented: $showingCreditosModal) {
            CreditosView()
        }
        .sheet(isPresented: $showingPaymentMethodsModal) {
            PaymentMethodsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showingCategoriesModal) {
            CategoriesView()
                .environmentObject(viewModel)
        }
        .alert("¿Estás seguro?", isPresented: $showingResetConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer", role: .destructive) {
                resetAllValues()
            }
        } message: {
            Text("Restablecer valores para comenzar un nuevo ciclo (se desmarcaran todos los ingresos, gastos y gastos de otras cuentas completados)")
        }
        .alert("Resultado", isPresented: $showingAlert) {
            Button("Aceptar", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func resetAllValues() {
        // Usar la misma función que el botón de reset en Ingresos y Gastos
        print("Restableciendo valores y comenzando un nuevo ciclo...")
        viewModel.resetCompletedTransactions()
    }
}

// Vista de créditos
struct CreditosView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("TusFinanzas")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Versión 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.vertical, 15)
                        
                        Text("Desarrollado por")
                            .font(.headline)
                        
                        Text("Angel Luis Rodriguez")
                            .font(.body)
                        
                        Spacer()
                            .frame(height: 20)
                        
                        Text("© 2025 Todos los derechos reservados")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color(.systemGroupedBackground))
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Acerca de", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cerrar") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// Vista de métodos de pago
struct PaymentMethodsView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var methods: [String] = []
    @State private var newMethod = ""
    @State private var isAddingNewMethod = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingMethod: String? = nil
    @State private var editedMethodName = ""
    @State private var isEditing = false
    @State private var methodToDelete: String? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Título centrado con fondo negro debajo de los botones
                Text("MÉTODOS DE PAGO")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                
                List {
                    Section(header: Text("Métodos actuales")) {
                        if methods.isEmpty {
                            Text("No hay métodos de pago configurados")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(methods, id: \.self) { method in
                                if isEditing && editingMethod == method {
                                    // Modo edición para este método
                                    HStack {
                                        TextField("Nuevo nombre", text: $editedMethodName)
                                            .autocapitalization(.words)
                                        
                                        Button(action: {
                                            saveEditedMethod()
                                        }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                        
                                        Button(action: {
                                            cancelEditing()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                } else {
                                    // Vista normal con botones de acción
                                    HStack {
                                        Text(method)
                                        
                                        Spacer()
                                        
                                        // Solo mostrar los botones de editar/eliminar si no es Efectivo
                                        if !isProtectedMethod(method) {
                                            Button(action: {
                                                startEditing(method)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(.horizontal, 4)
                                            
                                            Button(action: {
                                                confirmDeleteMethod(method)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(.horizontal, 4)
                                        } else {
                                            // Icono de candado para Efectivo
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                            .onMove(perform: moveItems)
                        }
                    }
                    
                    Section {
                        if isAddingNewMethod {
                            HStack {
                                TextField("Nuevo método", text: $newMethod)
                                    .autocapitalization(.words)
                                Button("Añadir") {
                                    addNewMethod()
                                }
                                .foregroundColor(.blue)
                                .disabled(newMethod.trimWhitespace().isEmpty)
                            }
                        } else {
                            Button(action: {
                                isAddingNewMethod = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Añadir método de pago")
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    EditButton()
                        .padding(.trailing, 8)
                    Button("Guardar") {
                        saveChanges()
                    }
                }
            )
            .onAppear(perform: loadPaymentMethods)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Atención"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Aceptar"))
                )
            }
            .alert("¿Eliminar método de pago?", isPresented: $showingDeleteConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let method = methodToDelete {
                        deleteMethod(method)
                        methodToDelete = nil
                    }
                }
            } message: {
                Text("¿Estás seguro que deseas eliminar este método de pago? Esta acción no se puede deshacer.")
            }
        }
    }
    
    // Verifica si un método es predefinido y no se puede modificar
    private func isProtectedMethod(_ method: String) -> Bool {
        // Solo "Efectivo" está protegido
        return method == PaymentMethod.cash.rawValue
    }
    
    // Verifica si un método está en los predefinidos
    private func isPredefinedMethod(_ method: String) -> Bool {
        let predefinedMethods = PaymentMethod.allCases
            .filter { $0 != .custom }
            .map { $0.rawValue }
        
        return predefinedMethods.contains(method)
    }
    
    // Función para mover elementos
    private func moveItems(from source: IndexSet, to destination: Int) {
        // Verificar si se intenta mover "Efectivo"
        let methodsToMove = source.map { methods[$0] }
        let containsProtected = methodsToMove.contains { isProtectedMethod($0) }
        
        if containsProtected {
            alertMessage = "No se puede mover el método de pago 'Efectivo'"
            showingAlert = true
            return
        }
        
        // Proceder con el movimiento
        methods.move(fromOffsets: source, toOffset: destination)
    }
    
    // Funciones para edición
    private func startEditing(_ method: String) {
        if isProtectedMethod(method) {
            alertMessage = "No se puede editar el método de pago 'Efectivo'"
            showingAlert = true
            return
        }
        
        editingMethod = method
        editedMethodName = method
        isEditing = true
    }
    
    private func saveEditedMethod() {
        if editingMethod == nil || editedMethodName.trimWhitespace().isEmpty {
            cancelEditing()
            return
        }
        
        let trimmedName = editedMethodName.trimWhitespace()
        
        // Verificar si ya existe este método
        if methods.contains(where: { $0.lowercased() == trimmedName.lowercased() && $0 != editingMethod }) {
            alertMessage = "Ya existe un método de pago con este nombre"
            showingAlert = true
            return
        }
        
        // Verificar si coincide con "Efectivo"
        if trimmedName.lowercased() == PaymentMethod.cash.rawValue.lowercased() {
            alertMessage = "No se puede usar el nombre 'Efectivo' por ser un método protegido"
            showingAlert = true
            return
        }
        
        // Actualizar el método
        if let index = methods.firstIndex(of: editingMethod!) {
            methods[index] = trimmedName
        }
        
        cancelEditing()
    }
    
    private func cancelEditing() {
        editingMethod = nil
        editedMethodName = ""
        isEditing = false
    }
    
    private func confirmDeleteMethod(_ method: String) {
        if isProtectedMethod(method) {
            alertMessage = "No se puede eliminar el método de pago 'Efectivo'"
            showingAlert = true
            return
        }
        
        methodToDelete = method
        showingDeleteConfirmation = true
    }
    
    private func deleteMethod(_ method: String) {
        if isProtectedMethod(method) {
            alertMessage = "No se puede eliminar el método de pago 'Efectivo'"
            showingAlert = true
            return
        }
        
        if let index = methods.firstIndex(of: method) {
            methods.remove(at: index)
            
            // Actualizar solo los métodos personalizados
            saveCustomMethodsToStorage()
        }
    }
    
    private func loadPaymentMethods() {
        // Cargar métodos de pago personalizados desde StorageManager
        let customMethods = StorageManager.shared.loadPaymentMethods()
        
        // Obtener métodos predefinidos (excluyendo custom)
        let predefinedMethods = PaymentMethod.allCases
            .filter { $0 != .custom }
            .map { $0.rawValue }
            
        // Combinar los métodos personalizados con los predefinidos, evitando duplicados
        var allMethods = predefinedMethods
        
        // Añadir métodos personalizados que no estén ya en los predefinidos
        for method in customMethods {
            if !predefinedMethods.contains(method) {
                allMethods.append(method)
            }
        }
        
        // Asignar la lista combinada
        methods = allMethods
        
        // Asegurar que el ViewModel tenga los métodos de pago actualizados
        viewModel.customPaymentMethods = methods.filter { !predefinedMethods.contains($0) }
        viewModel.reloadCustomPaymentMethods()
        
        print("PaymentMethodsView: Cargados \(methods.count) métodos de pago (\(predefinedMethods.count) predefinidos, \(methods.count - predefinedMethods.count) personalizados)")
    }
    
    private func addNewMethod() {
        let trimmedMethod = newMethod.trimWhitespace()
        
        if trimmedMethod.isEmpty {
            alertMessage = "El nombre del método de pago no puede estar vacío"
            showingAlert = true
            return
        }
        
        // Verificar si coincide con "Efectivo" (protegido)
        if trimmedMethod.lowercased() == PaymentMethod.cash.rawValue.lowercased() {
            alertMessage = "No se puede añadir otro método con el nombre 'Efectivo'"
            showingAlert = true
            return
        }
        
        // Verificar si ya existe en la lista actual
        if methods.contains(where: { $0.lowercased() == trimmedMethod.lowercased() }) {
            alertMessage = "Este método de pago ya existe"
            showingAlert = true
            return
        }
        
        methods.append(trimmedMethod)
        newMethod = ""
        isAddingNewMethod = false
        
        // Actualizar el almacenamiento
        saveCustomMethodsToStorage()
    }
    
    private func deleteMethods(at offsets: IndexSet) {
        // Verificar si se está intentando eliminar Efectivo
        let methodsToRemove = offsets.map { methods[$0] }
        let containsProtected = methodsToRemove.contains { isProtectedMethod($0) }
        
        if containsProtected {
            alertMessage = "No se puede eliminar el método de pago 'Efectivo'"
            showingAlert = true
            return
        }
        
        // Eliminar los métodos seleccionados
        methods.remove(atOffsets: offsets)
        
        // Actualizar el storage
        saveCustomMethodsToStorage()
    }
    
    private func saveChanges() {
        // Guardar métodos personalizados (no predefinidos) en el storage
        saveCustomMethodsToStorage()
        
        // Cerrar la vista
        presentationMode.wrappedValue.dismiss()
    }
    
    private func saveCustomMethodsToStorage() {
        // Obtener métodos personalizados
        let customMethods = methods.filter { !isPredefinedMethod($0) }
        
        // Guardar métodos personalizados en el StorageManager
        StorageManager.shared.savePaymentMethods(customMethods)
        
        // Actualizar el ViewModel con los métodos personalizados
        viewModel.customPaymentMethods = customMethods
        
        // Recargar los métodos en el ViewModel para toda la app
        viewModel.reloadCustomPaymentMethods()
        
        print("PaymentMethodsView: Se guardaron \(customMethods.count) métodos de pago personalizados")
    }
}

struct ConfiguracionView_Previews: PreviewProvider {
    static var previews: some View {
        ConfiguracionView()
            .environmentObject(FinanceViewModel())
    }
} 
