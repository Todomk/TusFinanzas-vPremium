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
    @State private var showingPasswordModal = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var expenseNotificationsEnabled = false
    @State private var notificationHour = 9
    @State private var notificationMinute = 0
    @State private var dayBeforeNotificationHour = 10
    @State private var dayBeforeNotificationMinute = 0
    
    private let languages = ["Español", "English"]
    
    // Inicializar el estado del toggle desde UserDefaults
    init() {
        _featuresEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "showTips"))
        _expenseNotificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "expenseNotificationsEnabled"))
        _notificationHour = State(initialValue: UserDefaults.standard.integer(forKey: "notificationHour") > 0 ? UserDefaults.standard.integer(forKey: "notificationHour") : 9)
        _notificationMinute = State(initialValue: UserDefaults.standard.integer(forKey: "notificationMinute") >= 0 ? UserDefaults.standard.integer(forKey: "notificationMinute") : 0)
        _dayBeforeNotificationHour = State(initialValue: UserDefaults.standard.integer(forKey: "dayBeforeNotificationHour") > 0 ? UserDefaults.standard.integer(forKey: "dayBeforeNotificationHour") : 10)
        _dayBeforeNotificationMinute = State(initialValue: UserDefaults.standard.integer(forKey: "dayBeforeNotificationMinute") >= 0 ? UserDefaults.standard.integer(forKey: "dayBeforeNotificationMinute") : 0)
    }
    
    private func updateNotificationTimes() {
        notificationHour = UserDefaults.standard.integer(forKey: "notificationHour")
        notificationMinute = UserDefaults.standard.integer(forKey: "notificationMinute")
        dayBeforeNotificationHour = UserDefaults.standard.integer(forKey: "dayBeforeNotificationHour")
        dayBeforeNotificationMinute = UserDefaults.standard.integer(forKey: "dayBeforeNotificationMinute")
    }
    
    // Añadir función auxiliar para formatear la fecha
    private func formatFecha(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Form {
            Section(header: Text("PREFERENCIAS")) {
                // Toggle para mostrar/ocultar propinas
                Toggle("Mostrar propinas", isOn: $featuresEnabled)
                    .tint(.blue)
                    .onChange(of: featuresEnabled) { newValue in
                        // Guardar el nuevo valor en UserDefaults
                        UserDefaults.standard.set(newValue, forKey: "showTips")
                        // Actualizar el ViewModel
                        viewModel.updateShowTipsPreference(newValue)
                    }
                
                // Toggle para notificaciones de gastos
                Toggle("Notificaciones de gastos", isOn: $expenseNotificationsEnabled)
                    .tint(.blue)
                    .onChange(of: expenseNotificationsEnabled) { newValue in
                        print("ConfiguracionView: Cambio en toggle de notificaciones: \(newValue)")
                        
                        // Guardar el nuevo valor en UserDefaults
                        UserDefaults.standard.set(newValue, forKey: "expenseNotificationsEnabled")
                        
                        if newValue {
                            // Si se activan las notificaciones, solicitar permiso y programar
                            print("ConfiguracionView: Activando notificaciones, solicitando permisos...")
                            NotificationManager.shared.requestPermission { granted in
                                DispatchQueue.main.async {
                                    if granted {
                                        print("ConfiguracionView: Permisos concedidos, programando notificaciones...")
                                        // Si se otorga permiso, programar notificaciones para gastos pendientes
                                        viewModel.scheduleExpenseNotifications()
                                    } else {
                                        print("ConfiguracionView: Permisos denegados, desactivando toggle...")
                                        // Si no se otorga permiso, desactivar la opción
                                        self.expenseNotificationsEnabled = false
                                        UserDefaults.standard.set(false, forKey: "expenseNotificationsEnabled")
                                        
                                        // Mostrar alerta al usuario
                                        let alert = UIAlertController(
                                            title: "Permisos denegados",
                                            message: "Para recibir notificaciones de gastos, necesitas permitir las notificaciones en la configuración de tu iPhone.",
                                            preferredStyle: .alert
                                        )
                                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let viewController = windowScene.windows.first?.rootViewController {
                                            viewController.present(alert, animated: true)
                                        }
                                    }
                                }
                            }
                        } else {
                            // Si se desactivan las notificaciones, cancelar todas las programadas
                            print("ConfiguracionView: Desactivando notificaciones, cancelando todas las programadas...")
                            NotificationManager.shared.cancelAllExpenseNotifications()
                        }
                    }
                // Mostrar el NavigationLink justo debajo del toggle, solo si está activado
                if expenseNotificationsEnabled {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Configurar horas de notificación")
                            Spacer()
                        }
                    }
                    // Mostrar las horas/minutos actuales debajo del enlace
                    Text("Mismo día: \(String(format: "%02d:%02d", notificationHour, notificationMinute))\nDía anterior: \(String(format: "%02d:%02d", dayBeforeNotificationHour, dayBeforeNotificationMinute))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                        .id("notificationTimes") // Forzar actualización cuando cambien los valores
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
                // Botón para restablecer valores - modificado para mostrar el modal de contraseña
                Button(action: {
                    showingPasswordModal = true
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
        // Nuevo modal para la contraseña
        .sheet(isPresented: $showingPasswordModal) {
            ResetPasswordView(viewModel: viewModel) { success in
                if success {
                    // El reset ya se realizó en la vista de contraseña
                    print("Reset completado con éxito")
                }
            }
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
    @State private var predefinedMethodsSet: Set<String> = []  // Set para verificar rápidamente
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
    
    // Verifica si un método es predefinido
    private func isPredefinedMethod(_ method: String) -> Bool {
        return predefinedMethodsSet.contains(method)
    }
    
    // NUEVO: Función que determina si un método es editable (cualquiera excepto Efectivo)
    private func isEditableMethod(_ method: String) -> Bool {
        return method != PaymentMethod.cash.rawValue
    }
    
    // Solo el método "Efectivo" está protegido
    private func isProtectedMethod(_ method: String) -> Bool {
        return method == PaymentMethod.cash.rawValue
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
        
        // Imprimir el nuevo orden para depuración
        print("PaymentMethodsView: Nuevo orden después de mover:")
        for (index, method) in methods.enumerated() {
            let tipo = predefinedMethodsSet.contains(method) ? "predefinido" : "personalizado"
            print("  \(index + 1). \(method) (\(tipo))")
        }
        
        // Guardar inmediatamente los cambios después de mover
        saveMethodsToStorage()
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
            
            // Guardar los cambios después de editar
            saveMethodsToStorage()
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
            
            // Guardar los cambios después de eliminar
            saveMethodsToStorage()
        }
    }
    
    private func loadPaymentMethods() {
        // Obtener los métodos predefinidos originales (solo para referencia)
        let predefinedMethods = PaymentMethod.allCases.map { $0.rawValue }
            
        // Guardar un set de los métodos predefinidos para verificaciones rápidas
        predefinedMethodsSet = Set(predefinedMethods)
        
        // Intentar cargar el orden completo primero
        let savedOrder = StorageManager.shared.loadMethodsOrder()
        
        if !savedOrder.isEmpty {
            // Si tenemos un orden guardado, usamos ese
            methods = savedOrder
            
            // Verificar si hay nuevos métodos predefinidos que no estén en la lista
            // y asegurar que "Efectivo" siempre esté presente
            for method in predefinedMethods {
                if !methods.contains(method) {
                    // Si es "Efectivo", asegurarnos de que esté en la lista
                    if method == PaymentMethod.cash.rawValue {
                        // Añadir al principio
                        methods.insert(method, at: 0)
                    }
                }
            }
            
            print("PaymentMethodsView: Cargando orden guardado:")
        } else {
            // Si no hay orden guardado, usamos el orden por defecto
            // Primero predefinidos, luego personalizados
            let customMethods = StorageManager.shared.loadPaymentMethods()
            methods = predefinedMethods
            
        for method in customMethods {
                if !methods.contains(method) {
                    methods.append(method)
            }
        }
        
            print("PaymentMethodsView: Cargando orden por defecto:")
        }
        
        // Mostrar el orden cargado
        for (index, method) in methods.enumerated() {
            let tipo = predefinedMethodsSet.contains(method) ? "predefinido" : "personalizado"
            print("  \(index + 1). \(method) (\(tipo))")
        }
        
        // Actualizar el ViewModel
        updateViewModelMethods()
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
        
        // Guardar los cambios
        saveMethodsToStorage()
    }
    
    // Métodos personalizados que guardamos para mantener compatibilidad
    // Ahora incluye tanto los personalizados como los predefinidos modificados o reordenados
    private func getCustomMethodsToSave() -> [String] {
        return methods.filter { !isProtectedMethod($0) && !predefinedMethodsSet.contains($0) }
    }
    
    // Extrae y guarda los métodos personalizados
    private func saveMethodsToStorage() {
        print("PaymentMethodsView: Guardando orden actual de métodos:")
        for (index, method) in methods.enumerated() {
            let tipo = predefinedMethodsSet.contains(method) ? "predefinido" : "personalizado"
            print("  \(index + 1). \(method) (\(tipo))")
        }
        
        // Primero guardamos el orden completo
        StorageManager.shared.saveMethodsOrder(methods)
        
        // Luego guardamos los métodos personalizados para compatibilidad
        // Aquí solo guardamos los que no son predefinidos originales
        let customMethods = getCustomMethodsToSave()
        StorageManager.shared.savePaymentMethods(customMethods)
        
        // Actualizar el ViewModel
        updateViewModelMethods()
        }
        
    // Actualiza el ViewModel con los métodos actuales
    private func updateViewModelMethods() {
        // Extraer los métodos personalizados y predefinidos modificados
        let customMethods = getCustomMethodsToSave()
        
        // Actualizar el ViewModel y recargar
        viewModel.customPaymentMethods = customMethods
        viewModel.reloadCustomPaymentMethods()
    }
    
    private func saveChanges() {
        print("PaymentMethodsView: Guardando cambios finales")
        for (index, method) in methods.enumerated() {
            let tipo = predefinedMethodsSet.contains(method) ? "predefinido" : "personalizado"
            print("  \(index + 1). \(method) (\(tipo))")
        }
        
        // Guardar todo de manera explícita para asegurar que se mantiene el orden
        StorageManager.shared.saveMethodsOrder(methods)
        
        // También guardar los métodos personalizados para compatibilidad
        let customMethods = getCustomMethodsToSave()
        StorageManager.shared.savePaymentMethods(customMethods)
        
        // Actualizar el ViewModel con los métodos personalizados
        viewModel.customPaymentMethods = customMethods
        
        // Forzar actualización inmediata en el ViewModel antes de cerrar
        DispatchQueue.main.async {
            // Recargar explícitamente los métodos en el ViewModel
            self.viewModel.reloadCustomPaymentMethods()
        
            print("PaymentMethodsView: Cambios guardados y vista cerrada")
            
            // Cerrar la vista después de asegurar que los cambios se aplicaron
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

// NUEVA VISTA - ResetPasswordView
struct ResetPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    var viewModel: FinanceViewModel
    var onComplete: (Bool) -> Void
    
    @State private var step = 0
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Contenido que varía según el paso actual
                Group {
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
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("Restablecer valores", displayMode: .inline)
            .navigationBarItems(trailing: 
                Button("Cancelar") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                // Determinar el paso inicial según si hay contraseña guardada
                if UserDefaults.standard.string(forKey: "resetPasswordKey") != nil {
                    step = 2
                } else {
                    step = 1
                }
            }
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
                presentationMode.wrappedValue.dismiss()
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
            // Ejecutamos la función de reset
            viewModel.resetCompletedTransactions()
            
            // Mostrar pantalla de éxito
            step = 4
        }
    }
}

struct ConfiguracionView_Previews: PreviewProvider {
    static var previews: some View {
        ConfiguracionView()
            .environmentObject(FinanceViewModel())
    }
} 