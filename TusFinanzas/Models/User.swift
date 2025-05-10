import Foundation

struct User: Codable, Identifiable {
    var id: String
    var name: String
    var surname: String
    var email: String
    var country: String
    var state: String
    var city: String
    var postalCode: String
    let subscriptionType: SubscriptionType
    
    enum SubscriptionType: String, Codable {
        case free = "Gratuita"
        case premium = "Premium"
    }
    
    init(id: String = UUID().uuidString,
         name: String = "",
         surname: String = "",
         email: String = "",
         country: String = "",
         state: String = "",
         city: String = "",
         postalCode: String = "",
         subscriptionType: SubscriptionType = .premium) {
        self.id = id
        self.name = name
        self.surname = surname
        self.email = email
        self.country = country
        self.state = state
        self.city = city
        self.postalCode = postalCode
        self.subscriptionType = subscriptionType
    }
} 