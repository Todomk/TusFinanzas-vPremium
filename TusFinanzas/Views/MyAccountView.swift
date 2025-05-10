import SwiftUI
import MessageUI

struct MyAccountView: View {
    enum Field {
        case name, surname, email, state, city, postalCode
    }
    
    @Binding var isPresented: Bool
    @StateObject private var locationService = LocationService()
    @StateObject private var userService = UserService()
    @State private var user: User = User()
    @State private var originalUser: User = User()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingMailComposer = false
    @State private var mailComposer: MFMailComposeViewController?
    @FocusState private var focusedField: Field?
    
    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
    
    private var hasChanges: Bool {
        return user.name != originalUser.name ||
               user.surname != originalUser.surname ||
               user.email != originalUser.email ||
               user.country != originalUser.country ||
               user.state != originalUser.state ||
               user.city != originalUser.city ||
               user.postalCode != originalUser.postalCode
    }
    
    init(isPresented: Binding<Bool> = .constant(true)) {
        _isPresented = isPresented
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("ID")
                    Spacer()
                    Text(user.id)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nombre")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    TextField("", text: $user.name)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .name)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apellidos")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    TextField("", text: $user.surname)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .surname)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    TextField("", text: $user.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("País")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Menu {
                        ForEach([""] + locationService.countries, id: \.self) { country in
                            Button(action: {
                                if user.country != country {
                                    user.country = country
                                    if country == "España" {
                                        locationService.fetchStates(forCountry: country)
                                    } else {
                                        locationService.states = []
                                    }
                                    // Limpiar campos dependientes
                                    user.state = ""
                                    user.city = ""
                                    user.postalCode = ""
                                }
                            }) {
                                Text(country.isEmpty ? "Selecciona un país" : country)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        HStack {
                            Text(user.country.isEmpty ? "Selecciona un país" : user.country)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                if !user.country.isEmpty {
                    if user.country == "España" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Provincia")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Menu {
                                ForEach([""] + locationService.states, id: \.self) { state in
                                    Button(action: {
                                        if user.state != state {
                                            user.state = state
                                            // Limpiar campos dependientes
                                            user.city = ""
                                            user.postalCode = ""
                                        }
                                    }) {
                                        Text(state.isEmpty ? "Selecciona una provincia" : state)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(user.state.isEmpty ? "Selecciona una provincia" : user.state)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estado/Región")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            TextField("", text: $user.state)
                                .textContentType(.addressState)
                                .focused($focusedField, equals: .state)
                                .onChange(of: user.state) { newState in
                                    if user.state != newState {
                                        user.city = ""
                                        user.postalCode = ""
                                    }
                                }
                        }
                    }
                }
                
                if !user.country.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Población")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        TextField("", text: $user.city)
                            .textContentType(.addressCity)
                            .focused($focusedField, equals: .city)
                            .onChange(of: user.city) { _ in
                                user.postalCode = ""
                            }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Código Postal")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    TextField("", text: $user.postalCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .postalCode)
                }
            }
            
            Section {
                HStack {
                    Text("Tipo de suscripción")
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Premium")
                            .foregroundColor(.orange)
                            .bold()
                        Text("Ver.: 1.0")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section {
                Button(action: saveUserData) {
                    Text("Guardar cambios")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(hasChanges ? Color.blue : Color.gray)
                .disabled(!hasChanges)
            }
        }
        .navigationTitle("Mi Cuenta")
        .onAppear {
            loadUserData()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    focusedField = nil
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Aviso"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage == "Datos guardados correctamente" {
                        isPresented = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(mailComposer: $mailComposer)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMailComposer"))) { notification in
            if let composer = notification.userInfo?["mailComposer"] as? MFMailComposeViewController {
                mailComposer = composer
                showingMailComposer = true
            }
        }
    }
    
    private func loadUserData() {
        if let currentUser = userService.currentUser {
            user = currentUser
            originalUser = currentUser
            loadLocationData()
        }
    }
    
    private func loadLocationData() {
        if user.country == "España" {
            locationService.fetchStates(forCountry: user.country)
        }
    }
    
    private func saveUserData() {
        // Validar email
        if !user.email.isEmpty && !emailPredicate.evaluate(with: user.email) {
            alertMessage = "Por favor, introduce un email válido"
            showingAlert = true
            return
        }
        
        // Validar campos requeridos
        if user.name.isEmpty {
            alertMessage = "Por favor, introduce tu nombre"
            showingAlert = true
            return
        }
        
        if user.surname.isEmpty {
            alertMessage = "Por favor, introduce tus apellidos"
            showingAlert = true
            return
        }
        
        if !user.country.isEmpty && user.state.isEmpty {
            let mensaje = user.country == "España" ? 
                "Por favor, selecciona una provincia" : 
                "Por favor, introduce un estado o región"
            alertMessage = mensaje
            showingAlert = true
            return
        }
        
        if !user.state.isEmpty && user.city.isEmpty {
            alertMessage = "Por favor, introduce una población"
            showingAlert = true
            return
        }
        
        // Guardar datos
        do {
            let savedUser = try userService.saveUser(user)
            user = savedUser
            originalUser = savedUser
            
            // Enviar correo de bienvenida solo si es la primera vez
            if userService.currentUser == nil {
                userService.sendWelcomeEmail(to: savedUser)
            }
            
            alertMessage = "Datos guardados correctamente"
            showingAlert = true
        } catch {
            alertMessage = "Error al guardar los datos: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// Vista para mostrar el compositor de correo
struct MailComposerView: UIViewControllerRepresentable {
    @Binding var mailComposer: MFMailComposeViewController?
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard let composer = mailComposer else {
            return UIViewController()
        }
        composer.mailComposeDelegate = context.coordinator
        return composer
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController,
                                 didFinishWith result: MFMailComposeResult,
                                 error: Error?) {
            controller.dismiss(animated: true)
        }
    }
} 