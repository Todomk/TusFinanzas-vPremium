import SwiftUI
// Usando String.trimWhitespace() definido en StringExtensions.swift

// Vista de Categorías personalizadas
struct CategoriesView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var categories: [String] = []
    @State private var predefinedCategoriesSet: Set<String> = []  // Set para verificación rápida
    @State private var newCategory = ""
    @State private var isAddingNewCategory = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingCategory: String? = nil
    @State private var editedCategoryName = ""
    @State private var isEditing = false
    @State private var categoryToDelete: String? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Título centrado con fondo negro debajo de los botones
                Text("CATEGORÍAS")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                
                List {
                    Section(header: Text("Categorías actuales")) {
                        if categories.isEmpty {
                            Text("No hay categorías personalizadas configuradas")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(categories, id: \.self) { category in
                                if isEditing && editingCategory == category {
                                    // Modo edición para esta categoría
                                    HStack {
                                        TextField("Nuevo nombre", text: $editedCategoryName)
                                            .autocapitalization(.words)
                                        
                                        Button(action: {
                                            saveEditedCategory()
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
                                        Text(category)
                                        
                                        Spacer()
                                        
                                        // Solo mostrar los botones de editar/eliminar si no es una categoría predefinida
                                        if !isProtectedCategory(category) {
                                            Button(action: {
                                                startEditing(category)
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(.horizontal, 4)
                                            
                                            Button(action: {
                                                confirmDeleteCategory(category)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            .padding(.horizontal, 4)
                                        } else {
                                            // Icono de candado para categorías predefinidas
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
                        if isAddingNewCategory {
                            HStack {
                                TextField("Nueva categoría", text: $newCategory)
                                    .autocapitalization(.words)
                                Button("Añadir") {
                                    addNewCategory()
                                }
                                .foregroundColor(.blue)
                                .disabled(newCategory.trimWhitespace().isEmpty)
                            }
                        } else {
                            Button(action: {
                                isAddingNewCategory = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Añadir categoría")
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
            .onAppear(perform: loadCategories)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Atención"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Aceptar"))
                )
            }
            .alert("¿Eliminar categoría?", isPresented: $showingDeleteConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                        categoryToDelete = nil
                    }
                }
            } message: {
                Text("¿Estás seguro que deseas eliminar esta categoría? Esta acción no se puede deshacer.")
            }
        }
    }
    
    // Verifica si una categoría es predefinida y no se puede modificar
    private func isProtectedCategory(_ category: String) -> Bool {
        // Solo "Otros" está protegida
        return category == "Otros"
    }
    
    // Función para mover elementos
    private func moveItems(from source: IndexSet, to destination: Int) {
        // Verificar si se intenta mover la categoría "Otros"
        let categoriesToMove = source.map { categories[$0] }
        let containsProtected = categoriesToMove.contains { isProtectedCategory($0) }
        
        if containsProtected {
            alertMessage = "No se puede mover la categoría 'Otros'"
            showingAlert = true
            return
        }
        
        // Verificar si se intenta colocar algo después de "Otros" (que debe estar siempre al final)
        let otrosIndex = categories.firstIndex(of: "Otros")
        if let otrosIdx = otrosIndex, destination > otrosIdx {
            alertMessage = "No se pueden mover categorías después de 'Otros'"
            showingAlert = true
            return
        }
        
        // Proceder con el movimiento
        categories.move(fromOffsets: source, toOffset: destination)
        
        // Imprimir el nuevo orden para depuración
        print("CategoriesView: Nuevo orden después de mover:")
        for (index, category) in categories.enumerated() {
            let tipo = predefinedCategoriesSet.contains(category) ? "predefinida" : "personalizada"
            print("  \(index + 1). \(category) (\(tipo))")
        }
        
        // Guardar inmediatamente los cambios después de mover
        saveCategoriesStorage()
    }
    
    // Funciones para edición
    private func startEditing(_ category: String) {
        if isProtectedCategory(category) {
            alertMessage = "No se puede editar la categoría 'Otros'"
            showingAlert = true
            return
        }
        
        editingCategory = category
        editedCategoryName = category
        isEditing = true
    }
    
    private func saveEditedCategory() {
        if editingCategory == nil || editedCategoryName.trimWhitespace().isEmpty {
            cancelEditing()
            return
        }
        
        let trimmedName = editedCategoryName.trimWhitespace()
        
        // Verificar si ya existe esta categoría
        if categories.contains(where: { $0.lowercased() == trimmedName.lowercased() && $0 != editingCategory }) {
            alertMessage = "Ya existe una categoría con este nombre"
            showingAlert = true
            return
        }
        
        // Verificar que no coincida con la categoría "Otros"
        if trimmedName.lowercased() == "Otros".lowercased() {
            alertMessage = "No se puede usar el nombre 'Otros' por ser una categoría protegida"
            showingAlert = true
            return
        }
        
        // Actualizar la categoría
        if let index = categories.firstIndex(of: editingCategory!) {
            categories[index] = trimmedName
            
            // Guardar los cambios después de editar
            saveCategoriesStorage()
        }
        
        cancelEditing()
    }
    
    private func cancelEditing() {
        editingCategory = nil
        editedCategoryName = ""
        isEditing = false
    }
    
    private func confirmDeleteCategory(_ category: String) {
        if isProtectedCategory(category) {
            alertMessage = "No se puede eliminar la categoría 'Otros'"
            showingAlert = true
            return
        }
        
        categoryToDelete = category
        showingDeleteConfirmation = true
    }
    
    private func deleteCategory(_ category: String) {
        if isProtectedCategory(category) {
            alertMessage = "No se puede eliminar la categoría 'Otros'"
            showingAlert = true
            return
        }
        
        if let index = categories.firstIndex(of: category) {
            categories.remove(at: index)
            
            // Guardar los cambios después de eliminar
            saveCategoriesStorage()
        }
    }
    
    private func loadCategories() {
        // Obtener todas las categorías predefinidas para referencia
        let predefinedCategoriesArray = GPCategory.allCases.map { $0.rawValue }
        
        // Guardar un set para verificación rápida
        predefinedCategoriesSet = Set(predefinedCategoriesArray)
        
        // Intentar cargar el orden completo primero
        let savedOrder = StorageManager.shared.loadCategoriesOrder()
        
        if !savedOrder.isEmpty {
            // Si tenemos un orden guardado, lo usamos
            categories = savedOrder
            
            // Asegurar que la categoría "Otros" esté siempre presente y al final
            if let otrosIndex = categories.firstIndex(of: "Otros") {
                // Si "Otros" está en la lista pero no al final, moverlo
                if otrosIndex != categories.count - 1 {
                    categories.remove(at: otrosIndex)
                    categories.append("Otros")
                }
            } else {
                // Si "Otros" no está en la lista, agregarlo al final
                categories.append("Otros")
            }
            
            print("CategoriesView: Cargando orden guardado:")
        } else {
            // Si no hay orden guardado, usar el orden predeterminado
            
            // Cargar categorías personalizadas
            let customCategories = viewModel.customCategories
        
            // Obtener categorías predefinidas (excluyendo "Otros")
            let predefinedCategoriesWithoutOtros = predefinedCategoriesArray.filter { $0 != "Otros" }
            
            // Iniciar la lista con categorías predefinidas (sin "Otros")
            categories = predefinedCategoriesWithoutOtros
        
            // Añadir categorías personalizadas
        for category in customCategories {
                if !categories.contains(category) && category != "Otros" {
                    categories.append(category)
            }
        }
        
        // Añadir "Otros" siempre al final
            categories.append("Otros")
        
            print("CategoriesView: Cargando orden predeterminado:")
        }
        
        // Mostrar el orden cargado
        for (index, category) in categories.enumerated() {
            let tipo = predefinedCategoriesSet.contains(category) ? "predefinida" : "personalizada"
            print("  \(index + 1). \(category) (\(tipo))")
        }
        
        // Actualizar el ViewModel
        updateViewModelCategories()
    }
    
    private func addNewCategory() {
        let trimmedCategory = newCategory.trimWhitespace()
        
        if trimmedCategory.isEmpty {
            alertMessage = "El nombre de la categoría no puede estar vacío"
            showingAlert = true
            return
        }
        
        // Verificar si coincide con "Otros" (protegido)
        if trimmedCategory.lowercased() == "Otros".lowercased() {
            alertMessage = "No se puede añadir otra categoría con el nombre 'Otros'"
            showingAlert = true
            return
        }
        
        // Verificar si ya existe en la lista actual
        if categories.contains(where: { $0.lowercased() == trimmedCategory.lowercased() }) {
            alertMessage = "Esta categoría ya existe"
            showingAlert = true
            return
        }
        
        // Añadir antes de "Otros" (que debe estar siempre al final)
        if let otrosIndex = categories.firstIndex(of: "Otros") {
            categories.insert(trimmedCategory, at: otrosIndex)
        } else {
            // Por si acaso no encontramos "Otros", añadir al final y luego añadir "Otros"
        categories.append(trimmedCategory)
            categories.append("Otros")
        }
        
        newCategory = ""
        isAddingNewCategory = false
        
        // Guardar los cambios
        saveCategoriesStorage()
    }
    
    private func saveChanges() {
        print("CategoriesView: Guardando cambios finales")
        for (index, category) in categories.enumerated() {
            let tipo = predefinedCategoriesSet.contains(category) ? "predefinida" : "personalizada"
            print("  \(index + 1). \(category) (\(tipo))")
        }
        
        // Guardar explícitamente para asegurar que se mantiene el orden
        // pero asegurando que "Otros" esté al final
        ensureOtrosAtEnd()
        
        // Guardar el orden completo
        StorageManager.shared.saveCategoriesOrder(categories)
        
        // También guardar solo las categorías personalizadas para compatibilidad
        let customCategories = getCustomCategoriesToSave()
        StorageManager.shared.saveCategories(customCategories)
        
        // Actualizar el ViewModel
        viewModel.customCategories = customCategories
        
        // Forzar actualización en el ViewModel antes de cerrar
        DispatchQueue.main.async {
            // Recargar explícitamente el ViewModel
            self.viewModel.reloadCustomCategories()
            
            print("CategoriesView: Cambios guardados y vista cerrada")
        
        // Cerrar la vista
            self.presentationMode.wrappedValue.dismiss()
    }
    }
    
    // Asegura que "Otros" esté siempre al final
    private func ensureOtrosAtEnd() {
        if let otrosIndex = categories.firstIndex(of: "Otros") {
            if otrosIndex != categories.count - 1 {
                categories.remove(at: otrosIndex)
                categories.append("Otros")
            }
        } else {
            // Si no hay "Otros", añadirlo
            categories.append("Otros")
        }
    }
    
    // Obtiene las categorías personalizadas para guardar (incluye predefinidas modificadas)
    private func getCustomCategoriesToSave() -> [String] {
        return categories.filter { !isProtectedCategory($0) && !predefinedCategoriesSet.contains($0) }
    }
    
    // Guarda todas las categorías
    private func saveCategoriesStorage() {
        // Asegurar que "Otros" esté al final
        ensureOtrosAtEnd()
        
        print("CategoriesView: Guardando orden actual de categorías:")
        for (index, category) in categories.enumerated() {
            let tipo = predefinedCategoriesSet.contains(category) ? "predefinida" : "personalizada"
            print("  \(index + 1). \(category) (\(tipo))")
        }
        
        // Guardar el orden completo
        StorageManager.shared.saveCategoriesOrder(categories)
        
        // También guardar solo las categorías personalizadas para compatibilidad
        let customCategories = getCustomCategoriesToSave()
        StorageManager.shared.saveCategories(customCategories)
        
        // Actualizar el ViewModel
        updateViewModelCategories()
    }
    
    // Actualiza el ViewModel con las categorías actuales
    private func updateViewModelCategories() {
        // Extraer las categorías personalizadas
        let customCategories = getCustomCategoriesToSave()
        
        // Actualizar el ViewModel
        viewModel.customCategories = customCategories
        viewModel.reloadCustomCategories()
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView()
            .environmentObject(FinanceViewModel())
    }
} 