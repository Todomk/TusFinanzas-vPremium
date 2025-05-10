import Foundation
import MessageUI

class UserService: ObservableObject {
    @Published var currentUser: User?
    private let userDefaults = UserDefaults.standard
    
    // Clave para almacenar el mapeo de email a ID
    private let emailToIdKey = "emailToIdMapping"
    
    init() {
        loadCurrentUser()
    }
    
    private func loadCurrentUser() {
        if let userData = userDefaults.data(forKey: "userData") {
            currentUser = try? JSONDecoder().decode(User.self, from: userData)
        }
    }
    
    func saveUser(_ user: User) throws -> User {
        var updatedUser = user
        
        // Verificar si ya existe un ID para este email
        if let existingId = getExistingUserId(for: user.email) {
            updatedUser.id = existingId
        }
        
        // Guardar el mapeo de email a ID
        saveEmailToIdMapping(email: user.email, id: updatedUser.id)
        
        // Guardar los datos del usuario
        let encoder = JSONEncoder()
        let userData = try encoder.encode(updatedUser)
        userDefaults.set(userData, forKey: "userData")
        currentUser = updatedUser
        
        return updatedUser
    }
    
    private func getExistingUserId(for email: String) -> String? {
        let mapping = userDefaults.dictionary(forKey: emailToIdKey) as? [String: String]
        return mapping?[email]
    }
    
    private func saveEmailToIdMapping(email: String, id: String) {
        var mapping = userDefaults.dictionary(forKey: emailToIdKey) as? [String: String] ?? [:]
        mapping[email] = id
        userDefaults.set(mapping, forKey: emailToIdKey)
    }
    
    func sendWelcomeEmail(to user: User) {
        let emailSubject = "¡Bienvenido/a a TusFinanzas!"
        let emailBody = """
        Hola \(user.name),
        
        ¡Bienvenido/a a TusFinanzas! Gracias por registrarte en nuestra aplicación.
        
        Tu ID único es: \(user.id)
        
        Con TusFinanzas podrás:
        - Gestionar tus ingresos y gastos
        - Controlar tus suscripciones
        - Hacer seguimiento de tus ahorros
        - Y mucho más...
        
        Si tienes alguna pregunta o sugerencia, no dudes en contactarnos.
        
        ¡Gracias por confiar en nosotros!
        
        El equipo de TusFinanzas
        """
        
        // Verificar si el dispositivo puede enviar correos
        if MFMailComposeViewController.canSendMail() {
            // Crear el controlador de composición de correo
            let mailComposer = MFMailComposeViewController()
            mailComposer.setToRecipients([user.email])
            mailComposer.setSubject(emailSubject)
            mailComposer.setMessageBody(emailBody, isHTML: false)
            
            // Notificar que el correo está listo para ser enviado
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowMailComposer"),
                object: nil,
                userInfo: ["mailComposer": mailComposer]
            )
        } else {
            // Si no se puede enviar correo, guardar para enviar más tarde
            print("El dispositivo no puede enviar correos en este momento")
        }
    }
} 