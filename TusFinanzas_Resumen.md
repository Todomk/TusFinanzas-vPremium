# 📱 TusFinanzas - Aplicación de Gestión Financiera Personal

## 🔍 **Resumen Ejecutivo**

**TusFinanzas** es una aplicación iOS desarrollada en SwiftUI para la gestión integral de finanzas personales. Permite a los usuarios controlar ingresos, gastos, suscripciones, propinas y gastos diarios con un sistema completo de categorización, periodicidad y seguimiento.

---

## 🏗️ **Arquitectura de la Aplicación**

### **Patrón de Arquitectura:** MVVM (Model-View-ViewModel)
- **Modelos:** `Transaction`, `User`
- **ViewModels:** `FinanceViewModel` (1,383 líneas - lógica principal)
- **Vistas:** SwiftUI con navegación por pestañas

### **Tecnologías Principales:**
- **SwiftUI** - Framework de interfaz de usuario
- **UIKit** - TabBarController personalizado
- **WidgetKit** - Widget para pantalla de inicio de iOS
- **UserDefaults** - Persistencia de datos local
- **App Groups** - Compartición de datos entre app y widget

---

## 💰 **Funcionalidades Principales**

### **1. Gestión de Transacciones**
La aplicación maneja **5 tipos principales** de transacciones:

#### **📈 Ingresos (`income`)**
- Salarios, freelance, inversiones
- Incluye opcionalmente propinas del mes actual
- Mostrar/ocultar propinas configurable

#### **📉 Gastos (`expense`)**
- Gastos fijos y variables
- Excluye automáticamente "Gastos Diarios"
- Categorización personalizada

#### **🔄 Suscripciones (`subscription`)**
- Servicios recurrentes (Netflix, Spotify, etc.)
- Gestión independiente de otros gastos

#### **💡 Propinas (`tips`)**
- Sistema semanal de registro
- Cálculo automático del total mensual
- Almacenamiento por fechas (`weeklyAmounts`)

#### **🛒 Gastos Personales/Diarios (`gp`)**
- Gastos cotidianos categorizados
- 9 categorías predefinidas + categorías personalizadas
- Entrada rápida mediante widget y deep linking

### **2. Sistema de Periodicidad**
Soporte completo para transacciones recurrentes:
- **Semanal** - Cada 7 días
- **Mensual** - Cada mes
- **Bimensual** - Cada 2 meses
- **Trimestral** - Cada 3 meses
- **Semestral** - Cada 6 meses
- **Anual** - Cada año
- **Bianual** - Cada 2 años

### **3. Métodos de Pago**
- **Efectivo**
- **Transferencia bancaria**
- **Tarjeta**
- **Domiciliación**
- **Bizum**
- **Métodos personalizados** (configurables por usuario)

### **4. Categorías de Gastos Personales**
#### **Categorías Predefinidas:**
1. 🍽️ Restauración
2. ⛽ Gasolina
3. 🛒 Supermercados y Alimentación
4. 👕 Ropa
5. 💻 Compra Online
6. 🏥 Salud
7. 💄 Belleza
8. 🎭 Ocio
9. 📦 Otros

#### **Categorías Personalizadas:**
- Los usuarios pueden crear categorías adicionales
- Almacenadas en `customCategories`

---

## 🖥️ **Interfaz de Usuario**

### **Navegación Principal (TabBar)**
La aplicación utiliza un `TabBarController` personalizado con 4 pestañas:

1. **📈 Ingresos**
   - Lista de transacciones de ingresos
   - Totales pendientes y completados
   - Incluye/excluye propinas según configuración

2. **📉 Gastos**
   - Lista de gastos (excluyendo gastos diarios)
   - Totales combinados con suscripciones y GP

3. **📊 Beneficios**
   - Cálculo automático: `(Ingresos) - (Gastos totales)`
   - Vista de resumen financiero

4. **⚙️ Más**
   - Acceso a configuración
   - Navegación a vistas especializadas:
     - Gastos Diarios (GP)
     - Propinas
     - Suscripciones
     - Configuración

### **Vistas Especializadas**

#### **Entrada Rápida de Gastos:**
- `QuickGPEntryView` - Modal para entrada rápida
- `AddGPTransactionView` - Vista completa para gastos detallados

#### **Gestión de Transacciones:**
- `TransactionListView` - Lista general de transacciones
- `EditTransactionView` - Edición de transacciones existentes
- `TransactionRow` - Componente de fila individual

#### **Configuración:**
- `ConfiguracionView` - Configuración general de la app
- `SettingsView` - Configuraciones específicas

---

## 🔗 **Deep Linking y Widget**

### **Esquema de URL:** `tusfinanzas://`
La aplicación soporta deep linking para:
- Abrir directamente la vista de gastos diarios
- Pre-rellenar formularios con datos específicos
- Navegación externa desde widgets

### **Widget de iOS:**
- **Archivo:** `TusFinanzaswidget.swift` (338 líneas)
- **Funcionalidad:** Entrada rápida de gastos desde pantalla de inicio
- **Datos compartidos:** Via App Groups (`group.com.rogalan.TusFinanzas`)

---

## 💾 **Gestión de Datos**

### **Persistencia:**
- **`StorageManager.swift`** - Gestión centralizada de datos
- **`UserDefaults`** - Almacenamiento local
- **App Groups** - Compartición entre app principal y widget

### **Estructura de Datos Principal:**
```swift
struct Transaction: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var concept: String
    var isCompleted: Bool
    var type: TransactionType
    var periodicity: Periodicity
    var paymentType: PaymentType
    var paymentMethod: PaymentMethod
    var customPaymentMethod: String?
    var startDate: Date?
    var endDate: Date?
    var lastResetDate: Date?
    var nextAppearanceDate: Date?
    var weeklyAmounts: [Date: Double]? // Para propinas
    var gpCategory: GPCategory?
    var customGPCategory: String?
    // ... más campos
}
```

### **ViewModel Principal:**
`FinanceViewModel` (1,383 líneas) maneja:
- **5 arrays de transacciones** por tipo
- **Cálculos automáticos** de totales
- **Sincronización** con widget
- **Validaciones** de negocio
- **Reseteo mensual** de transacciones

---

## 🔄 **Lógica de Negocio**

### **Cálculos Automáticos:**
```swift
// Totales calculados automáticamente
@Published private(set) var pendingIncome: Double = 0
@Published private(set) var completedIncome: Double = 0
@Published private(set) var totalIncome: Double = 0
@Published private(set) var totalExpenses: Double = 0
@Published private(set) var totalGP: Double = 0
// ... más totales
```

### **Filtrado Inteligente:**
- **Transacciones futuras** no se incluyen en cálculos
- **Propinas** se pueden mostrar/ocultar globalmente
- **Gastos diarios** se manejan por separado

### **Reseteo Mensual:**
- Funcionalidad para restablecer transacciones completadas
- Cálculo automático de próximas fechas de aparición
- Mantenimiento de periodicidad correcta

---

## 🛠️ **Servicios y Utilidades**

### **Servicios:**
- **`LocationService.swift`** (189 líneas) - Gestión de ubicación
- **`UserService.swift`** (93 líneas) - Gestión de usuario

### **Modelo de Usuario:**
```swift
struct User: Codable, Identifiable {
    var id: String
    var name: String
    var surname: String
    var email: String
    var country: String
    var state: String
    var city: String
    var postalCode: String
    let subscriptionType: SubscriptionType // .free o .premium
}
```

### **Utilidades Compartidas:**
- **`WidgetDataProvider.swift`** - Proveedor de datos para widget
- **`StringExtensions.swift`** - Extensiones de cadenas
- **Extensiones de fecha** para formateo

---

## 📱 **Configuración del Proyecto**

### **Bundle Identifier:** `com.carretas.TusFinanzas`
### **App Groups:** `group.com.rogalan.TusFinanzas`
### **Esquema URL:** `tusfinanzas://`

### **Targets del Proyecto:**
1. **TusFinanzas** - App principal
2. **TusFinanzaswidgetExtension** - Extensión del widget
3. **TusFinanzaswidget** - Directorio del widget

### **Scripts de Configuración:**
- **`fix_dependency.sh`** - Corrección de dependencias circulares
- **`fix_swift_tasks.sh`** - Corrección de tareas de compilación Swift

---

## 📈 **Estado del Desarrollo**

### **Archivos de Backup:**
La presencia de múltiples archivos `.bak` y versiones indica desarrollo activo:
- `TransactionViews.swift.v1.3.bak`
- `FinanceViewModel.swift.v1.3.bak`
- Múltiples versiones de backup con timestamps

### **Logs de Compilación:**
- `build_output.txt` (887 líneas)
- `build_log_verbose.txt`
- Evidencia de debugging y optimización continua

---

## 🎯 **Características Destacadas**

### **1. Gestión Inteligente de Fechas**
- Cálculo automático de próximas apariciones
- Soporte para transacciones futuras
- Algoritmo complejo de periodicidad (506 líneas en Transaction.swift)

### **2. Widget Integrado**
- Entrada rápida desde pantalla de inicio
- Sincronización bidireccional de datos
- Soporte para diferentes tamaños de widget

### **3. Deep Linking Avanzado**
- Navegación directa a secciones específicas
- Pre-rellenado de formularios
- Integración con sistema de notificaciones

### **4. Personalización Completa**
- Métodos de pago personalizados
- Categorías personalizadas
- Configuración flexible de visualización

### **5. Cálculos Financieros Robustos**
- Separación clara entre tipos de transacciones
- Cálculos automáticos de beneficios
- Manejo de propinas por períodos semanales

---

## 🔧 **Aspectos Técnicos Avanzados**

### **Manejo de Estado:**
- Uso extensivo de `@Published` para reactividad
- Sincronización automática con almacenamiento
- Validaciones en tiempo real

### **Optimización de Rendimiento:**
- Cálculos derivados solo cuando es necesario
- Filtrado eficiente de transacciones
- Gestión de memoria optimizada

### **Debugging y Logging:**
- Sistema extenso de logs para debugging
- Pruebas automáticas de cálculos de fechas
- Verificación de consistencia de datos

---

## 📋 **Resumen de Archivos Principales**

| Archivo | Líneas | Descripción |
|---------|--------|-------------|
| `FinanceViewModel.swift` | 1,383 | Lógica principal de negocio |
| `TransactionListView.swift` | 792 | Vista principal de transacciones |
| `TipsView.swift` | 694 | Gestión de propinas |
| `Transaction.swift` | 669 | Modelo de datos principal |
| `ConfiguracionView.swift` | 551 | Configuración de la app |
| `ContentView.swift` | 358 | Vista principal con TabBar |
| `TusFinanzaswidget.swift` | 338 | Widget de iOS |

---

## 🎨 **Conclusión**

TusFinanzas es una aplicación financiera personal **completa y sofisticada** que demuestra:

- **Arquitectura sólida** con separación clara de responsabilidades
- **Funcionalidades avanzadas** como widgets nativos y deep linking
- **Gestión inteligente de datos** con cálculos automáticos complejos
- **Interfaz de usuario moderna** siguiendo las mejores prácticas de iOS
- **Personalización extensa** para adaptarse a diferentes necesidades

La aplicación está en **desarrollo activo** con múltiples versiones de backup y optimizaciones continuas, indicando un proyecto maduro y en evolución constante.