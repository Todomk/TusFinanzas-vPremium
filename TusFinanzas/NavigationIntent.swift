import Foundation
import Combine

class NavigationIntent: ObservableObject {
    @Published var goToPropinas: Bool = false
    @Published var goToGastosDiarios: Bool = false
} 