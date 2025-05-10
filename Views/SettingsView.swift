import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: FinanceViewModel
    
    // Opciones de configuración
    @State private var enableNotifications: Bool = true
    @State private var defaultPaymentMethod: PaymentMethod = .card
    @State private var showWidgets: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preferencias generales")) {
                    Toggle("Activar notificaciones", isOn: $enableNotifications)
                    
                    Picker("Método de pago predeterminado", selection: $defaultPaymentMethod) {
                        Text("Efectivo").tag(PaymentMethod.cash)
                        Text("Transferencia").tag(PaymentMethod.bank)
                        Text("Tarjeta").tag(PaymentMethod.card)
                    }
                }
                
                Section(header: Text("Widgets")) {
                    Toggle("Mostrar widgets", isOn: $showWidgets)
                    
                    NavigationLink(destination: WidgetConfigView()) {
                        HStack {
                            Image(systemName: "apps.iphone")
                            Text("Configuración de widgets")
                        }
                    }
                }
                
                Section(header: Text("Datos")) {
                    Button(action: {
                        // Acción para exportar datos
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Exportar datos")
                        }
                    }
                    
                    Button(action: {
                        // Acción para importar datos
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Importar datos")
                        }
                    }
                    
                    Button(action: {
                        // Acción para restablecer datos
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Restablecer datos")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("Información")) {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct WidgetConfigView: View {
    @State private var selectedWidget: String = "Principal"
    @State private var widgetKind: String = "TusFinanzaswidget"
    @State private var widgetFamily: String = "medium"
    @State private var widgetView: String = "timeline"
    @State private var showSuccessMessage: Bool = false
    
    private let widgetFamilies = ["small", "medium", "large"]
    private let widgetViews = ["timeline", "placeholder", "snapshot"]
    
    var body: some View {
        Form {
            Section(header: Text("Tipo de widget")) {
                Picker("Widget", selection: $selectedWidget) {
                    Text("Principal").tag("Principal")
                    Text("Entrada rápida").tag("QuickEntry")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedWidget) { newValue in
                    if newValue == "Principal" {
                        widgetKind = "TusFinanzaswidget"
                    } else {
                        widgetKind = "QuickEntryWidget"
                    }
                }
            }
            
            Section(header: Text("Configuración técnica")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Widget Kind")
                        .font(.headline)
                    TextField("Widget Kind", text: $widgetKind)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tamaño")
                        .font(.headline)
                    Picker("Tamaño del widget", selection: $widgetFamily) {
                        ForEach(widgetFamilies, id: \.self) { family in
                            Text(family.capitalized).tag(family)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vista por defecto")
                        .font(.headline)
                    Picker("Vista por defecto", selection: $widgetView) {
                        ForEach(widgetViews, id: \.self) { view in
                            Text(view.capitalized).tag(view)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Button(action: {
                    saveWidgetConfiguration()
                    showSuccessMessage = true
                    // Ocultar mensaje después de 2 segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSuccessMessage = false
                    }
                }) {
                    Text("Guardar configuración")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            Section(header: Text("Ayuda")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuración del Widget")
                        .font(.headline)
                    Text("Estas variables se utilizan para configurar correctamente el widget en Xcode. Para aplicar la configuración, asegúrate de que el widget está correctamente instalado en tu pantalla de inicio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cómo usar los widgets")
                        .font(.headline)
                    Text("1. Mantén pulsada la pantalla de inicio\n2. Pulsa en el botón '+' en la esquina superior\n3. Busca 'TusFinanzas'\n4. Elige el widget y añádelo a tu pantalla")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if showSuccessMessage {
                    VStack {
                        Text("¡Configuración guardada!")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut)
                }
            }, alignment: .bottom
        )
    }
    
    private func saveWidgetConfiguration() {
        // Guardamos la configuración en UserDefaults para que Xcode la utilice
        let userDefaults = UserDefaults.standard
        userDefaults.set(widgetKind, forKey: "WidgetKind")
        userDefaults.set(widgetFamily, forKey: "WidgetFamily")
        userDefaults.set(widgetView, forKey: "WidgetDefaultView")
        
        // En iOS no podemos guardar en el directorio de configuración de Xcode,
        // ya que es una configuración que sólo tiene sentido en el entorno de desarrollo
        if saveWidgetConfigToUserDefaults() {
            print("Configuración de widget guardada correctamente")
        }
    }
    
    private func saveWidgetConfigToUserDefaults() -> Bool {
        do {
            // Guardamos la configuración en UserDefaults con un grupo para compartir con la app
            let sharedDefaults = UserDefaults(suiteName: "group.com.carretas.TusFinanzas")
            
            // Guardar cada variable
            sharedDefaults?.set(widgetKind, forKey: "_XCWidgetKind")
            sharedDefaults?.set(widgetFamily, forKey: "_XCWidgetFamily")
            sharedDefaults?.set(widgetView, forKey: "_XCWidgetDefaultView")
            
            // Guardar también los valores en un diccionario para que puedan ser accedidos por el widget
            let widgetConfig: [String: Any] = [
                "WidgetKind": widgetKind,
                "WidgetFamily": widgetFamily,
                "WidgetDefaultView": widgetView,
                "LastUpdated": Date()
            ]
            
            sharedDefaults?.set(widgetConfig, forKey: "WidgetConfiguration")
            
            return true
        } catch {
            print("Error al guardar configuración del widget: \(error)")
            return false
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(FinanceViewModel())
    }
} 