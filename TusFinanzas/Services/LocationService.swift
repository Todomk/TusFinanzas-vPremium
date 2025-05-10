import Foundation

class LocationService: ObservableObject {
    @Published var countries: [String] = []
    @Published var states: [String] = []
    @Published var cities: [String] = []
    @Published var isLoadingCities = false
    @Published var errorMessage: String?
    
    // Diccionario para mapear nombres de provincias a sus códigos
    private let provinceCodesES: [String: String] = [
        "A Coruña": "C",
        "Álava": "VI",
        "Albacete": "AB",
        "Alicante": "A",
        "Almería": "AL",
        "Asturias": "O",
        "Ávila": "AV",
        "Badajoz": "BA",
        "Baleares": "PM",
        "Barcelona": "B",
        "Burgos": "BU",
        "Cáceres": "CC",
        "Cádiz": "CA",
        "Cantabria": "S",
        "Castellón": "CS",
        "Ciudad Real": "CR",
        "Córdoba": "CO",
        "Cuenca": "CU",
        "Girona": "GI",
        "Granada": "GR",
        "Guadalajara": "GU",
        "Guipúzcoa": "SS",
        "Huelva": "H",
        "Huesca": "HU",
        "Jaén": "J",
        "La Rioja": "LO",
        "Las Palmas": "GC",
        "León": "LE",
        "Lleida": "L",
        "Lugo": "LU",
        "Madrid": "M",
        "Málaga": "MA",
        "Murcia": "MU",
        "Navarra": "NA",
        "Ourense": "OR",
        "Palencia": "P",
        "Pontevedra": "PO",
        "Salamanca": "SA",
        "Santa Cruz de Tenerife": "TF",
        "Segovia": "SG",
        "Sevilla": "SE",
        "Soria": "SO",
        "Tarragona": "T",
        "Teruel": "TE",
        "Toledo": "TO",
        "Valencia": "V",
        "Valladolid": "VA",
        "Vizcaya": "BI",
        "Zamora": "ZA",
        "Zaragoza": "Z"
    ]
    
    private let geoNamesUsername = "tusfinanzas" // Nombre de usuario de GeoNames
    
    init() {
        loadCountries()
    }
    
    private func loadCountries() {
        // Lista de países europeos en español
        countries = [
            "Alemania",
            "Austria",
            "Bélgica",
            "Bulgaria",
            "Chipre",
            "Croacia",
            "Dinamarca",
            "Eslovaquia",
            "Eslovenia",
            "España",
            "Estonia",
            "Finlandia",
            "Francia",
            "Grecia",
            "Hungría",
            "Irlanda",
            "Italia",
            "Letonia",
            "Lituania",
            "Luxemburgo",
            "Malta",
            "Países Bajos",
            "Polonia",
            "Portugal",
            "República Checa",
            "Rumanía",
            "Suecia"
        ].sorted()
    }
    
    func fetchStates(forCountry country: String) {
        // Lista predefinida de estados/provincias para España
        if country == "España" {
            states = [
                "A Coruña", "Álava", "Albacete", "Alicante", "Almería", "Asturias",
                "Ávila", "Badajoz", "Baleares", "Barcelona", "Burgos", "Cáceres",
                "Cádiz", "Cantabria", "Castellón", "Ciudad Real", "Córdoba", "Cuenca",
                "Girona", "Granada", "Guadalajara", "Guipúzcoa", "Huelva", "Huesca",
                "Jaén", "La Rioja", "Las Palmas", "León", "Lleida", "Lugo", "Madrid",
                "Málaga", "Murcia", "Navarra", "Ourense", "Palencia", "Pontevedra",
                "Salamanca", "Santa Cruz de Tenerife", "Segovia", "Sevilla", "Soria",
                "Tarragona", "Teruel", "Toledo", "Valencia", "Valladolid", "Vizcaya",
                "Zamora", "Zaragoza"
            ].sorted()
        } else {
            states = []
        }
    }
    
    func fetchCities(forState state: String, inCountry country: String) {
        guard country == "España", let provinceCode = provinceCodesES[state] else {
            cities = []
            return
        }
        
        isLoadingCities = true
        cities = []
        errorMessage = nil
        
        // Construir la URL para la API de GeoNames
        // Usamos featureClass=P para poblaciones y maxRows=1000 para obtener un buen número de resultados
        let urlString = "http://api.geonames.org/searchJSON?country=ES&adminCode1=\(provinceCode)&featureClass=P&style=FULL&maxRows=1000&username=\(geoNamesUsername)"
        
        guard let url = URL(string: urlString) else {
            isLoadingCities = false
            errorMessage = "Error al construir la URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoadingCities = false
                
                if let error = error {
                    self?.errorMessage = "Error de red: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No se recibieron datos"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(GeoNamesResponse.self, from: data)
                    
                    // Filtrar y ordenar las poblaciones
                    self?.cities = response.geonames
                        .filter { $0.population > 0 } // Solo lugares habitados
                        .sorted { $0.population > $1.population } // Ordenar por población
                        .map { $0.name }
                } catch {
                    self?.errorMessage = "Error al procesar los datos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// Estructuras para decodificar la respuesta de GeoNames
struct GeoNamesResponse: Codable {
    let geonames: [GeoName]
}

struct GeoName: Codable {
    let name: String
    let population: Int
}

// Estructura para decodificar la respuesta de la API de países
struct CountryResponse: Codable {
    struct Name: Codable {
        let common: String
    }
    let name: Name
} 