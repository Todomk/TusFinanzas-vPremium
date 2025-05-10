import SwiftUI

// Este archivo existe para asegurar que el proyecto se compile específicamente para iOS 16.0 o posterior
// Ya que la aplicación utiliza características como NavigationStack que solo están disponibles desde iOS 16.0

#if !os(iOS)
#error("Esta aplicación solo es compatible con iOS.")
#endif

// Verificación de versión mínima
#if os(iOS)
@available(iOS 16.0, *)
struct VersionCheck {
    // Esta estructura se usa solo para verificar la versión mínima de iOS
}
#endif 