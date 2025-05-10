import SwiftUI
// Usando String.trimWhitespace() definido en StringExtensions.swift

// Vista de Categorías personalizadas
struct CategoriesView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var categories: [String] = []
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
        
        // Verificar que no coincida con una categoría predefinida
        if isProtectedCategory(trimmedName) {
            alertMessage = "No se puede usar el nombre de una categoría predefinida"
            showingAlert = true
            return
        }
        
        // Actualizar la categoría
        if let index = categories.firstIndex(of: editingCategory!) {
            categories[index] = trimmedName
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
            
            // Actualizar solo las categorías personalizadas
            saveCustomCategoriesToStorage()
        }
    }
    
    private func loadCategories() {
        // Cargar categorías personalizadas desde StorageManager
        let customCategories = StorageManager.shared.loadCategories()
        
        // Obtener categorías predefinidas (excluyendo "Otros" que irá al final)
        let predefinedCategories = GPCategory.allCases
            .filter { $0.rawValue != "Otros" }
            .map { $0.rawValue }
            
        // Iniciar la lista con las categorías predefinidas (sin "Otros")
        var allCategories = predefinedCategories
        
        // Añadir categorías personalizadas que no estén ya en las predefinidas
        for category in customCategories {
            if !predefinedCategories.contains(category) && category != "Otros" {
                allCategories.append(category)
            }
        }
        
        // Añadir "Otros" siempre al final
        allCategories.append("Otros")
        
        // Asignar la lista combinada
        categories = allCategories
        
        // Asegurar que el ViewModel tenga las categorías actualizadas
        viewModel.customCategories = customCategories
        viewModel.reloadCustomCategories()
        
        print("CategoriesView: Cargadas \(categories.count) categorías (\(predefinedCategories.count) predefinidas, \(customCategories.count) personalizadas)")
    }
    
    private func addNewCategory() {
        let trimmedCategory = newCategory.trimWhitespace()
        
        if trimmedCategory.isEmpty {
            alertMessage = "El nombre de la categoría no puede estar vacío"
            showingAlert = true
            return
        }
        
        // Verificar que no coincida con una categoría predefinida
        if isProtectedCategory(trimmedCategory) {
            alertMessage = "No se puede añadir una categoría con el mismo nombre que una predefinida"
            showingAlert = true
            return
        }
        
        // Verificar si ya existe en la lista actual
        if categories.contains(where: { $0.lowercased() == trimmedCategory.lowercased() }) {
            alertMessage = "Esta categoría ya existe"
            showingAlert = true
            return
        }
        
        categories.append(trimmedCategory)
        newCategory = ""
        isAddingNewCategory = false
        
        // Actualizar el almacenamiento
        saveCustomCategoriesToStorage()
    }
    
    private func saveChanges() {
        // Guardar categorías personalizadas (no predefinidas) en el storage
        saveCustomCategoriesToStorage()
        
        // Cerrar la vista
        presentationMode.wrappedValue.dismiss()
    }
    
    private func saveCustomCategoriesToStorage() {
        // Obtener categorías personalizadas
        let customCategories = categories.filter { !isProtectedCategory($0) }
        
        // Guardar categorías personalizadas en el StorageManager
        StorageManager.shared.saveCategories(customCategories)
        
        // Actualizar el ViewModel con las categorías personalizadas
        viewModel.customCategories = customCategories
        
        // Recargar las categorías en el ViewModel para toda la app
        viewModel.reloadCustomCategories()
        
        print("CategoriesView: Se guardaron \(customCategories.count) categorías personalizadas")
    }
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView()
            .environmentObject(FinanceViewModel())
    }
} 