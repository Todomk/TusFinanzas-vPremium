import SwiftUI

struct BenefitsView: View {
    @EnvironmentObject var viewModel: FinanceViewModel
    
    private func formatCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM"
        
        // Obtener la fecha actual
        let currentDate = Date()
        
        // Si se debe mostrar el mes siguiente (después de un reset)
        if viewModel.showNextMonth {
            let calendar = Calendar.current
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                return formatter.string(from: nextMonth).uppercased()
            }
        }
        
        return formatter.string(from: currentDate).uppercased()
    }
    
    private func formatCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        
        // Obtener la fecha actual
        let currentDate = Date()
        
        // Si se debe mostrar el mes siguiente y es diciembre
        if viewModel.showNextMonth {
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: currentDate)
            
            if currentMonth == 12 {
                if let nextYear = calendar.date(byAdding: .year, value: 1, to: currentDate) {
                    return formatter.string(from: nextYear)
                }
            }
        }
        
        return formatter.string(from: currentDate)
    }
    
    var body: some View {
        List {
            Section(header: 
                Text("Estado Real")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
            ) {
                Section {
                    HStack {
                        Text("Ingresos totales")
                            .foregroundColor(.white)
                        Spacer()
                        // Solo consideramos ingresos completados y propinas para Estado Real
                        let totalCobrado = viewModel.completedIncome
                        // Verificar si se deben mostrar las propinas
                        let showTips = UserDefaults.standard.bool(forKey: "showTips")
                        let totalPropinas = (showTips && viewModel.findTipsTransaction() != nil) ?
                            viewModel.getCurrentMonthTipsTotal(tipTransaction: viewModel.findTipsTransaction()!) : 0
                        
                        let totalIngresosCobrados = totalCobrado + totalPropinas
                        Text(String(format: "%.2f €", totalIngresosCobrados))
                            .foregroundColor(.white)
                            .bold()
                    }
                    
                    HStack {
                        Text("Gastos totales")
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Para Estado Real, solo utilizamos los gastos completados/pagados
                        let totalGastosPagados = viewModel.completedExpenses + viewModel.completedSubscriptions + viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.2f €", totalGastosPagados))
                                .foregroundColor(.white)
                                .bold()
                            
                            // Mostrar desglose simplificado
                            Text("Pagados: \(String(format: "%.2f", viewModel.completedExpenses))€ + GPgO: \(String(format: "%.2f", viewModel.completedSubscriptions))€ + GP: \(String(format: "%.2f", viewModel.gpTransactions.reduce(0) { $0 + $1.amount }))€")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .listSectionSeparator(.hidden)
                
                Section {
                    HStack {
                        Text("Total Beneficios")
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Calcular gastos totales para Estado Real (solo pagados)
                        let totalGastosPagados = viewModel.completedExpenses + viewModel.completedSubscriptions + viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                        
                        // Para Estado Real solo consideramos ingresos completados y propinas
                        let totalCobrado = viewModel.completedIncome
                        // Verificar si se deben mostrar las propinas
                        let showTips = UserDefaults.standard.bool(forKey: "showTips")
                        let totalPropinas = (showTips && viewModel.findTipsTransaction() != nil) ?
                            viewModel.getCurrentMonthTipsTotal(tipTransaction: viewModel.findTipsTransaction()!) : 0
                        
                        let totalIngresosCobrados = totalCobrado + totalPropinas
                        
                        let beneficios = totalIngresosCobrados - totalGastosPagados
                        Text(String(format: "%.2f €", beneficios))
                            .foregroundColor(.white)
                            .font(.title3)
                            .bold()
                    }
                }
                .listSectionSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)
            
            Section(header: 
                Text("Previsión")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
            ) {
                Section {
                    HStack {
                        Text("Ingresos totales")
                            .foregroundColor(.white)
                        Spacer()
                        let totalPendiente = viewModel.pendingIncome
                        let totalCobrado = viewModel.completedIncome
                        // Verificar si se deben mostrar las propinas
                        let showTips = UserDefaults.standard.bool(forKey: "showTips")
                        let totalPropinas = (showTips && viewModel.findTipsTransaction() != nil) ?
                            viewModel.getCurrentMonthTipsTotal(tipTransaction: viewModel.findTipsTransaction()!) : 0
                        
                        let granTotal = totalPendiente + totalCobrado + totalPropinas
                        Text(String(format: "%.2f €", granTotal))
                            .foregroundColor(.green)
                            .bold()
                    }
                    
                    HStack {
                        Text("Gastos totales")
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Usar la misma lógica que en TransactionListView:
                        
                        // 1. Todos los items del listado Pendientes
                        let pendingItems = viewModel.expenses.filter { 
                            !$0.isCompleted && isInCurrentMonthOrBefore(date: $0.startDate)
                        }.reduce(0) { $0 + $1.amount }
                        
                        // 2. Gastos pendientes de otras cuentas
                        let suscripcionesPendientes = viewModel.pendingSubscriptions
                        
                        // 3. Todos los items del listado Completados
                        let completedItems = viewModel.expenses.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                        
                        // 4. Gastos pagados de otras cuentas
                        let suscripcionesPagadas = viewModel.completedSubscriptions
                        
                        // 5. Gastos diarios
                        let gastosDiarios = viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                        
                        // Sumar todos los componentes
                        let totalGastos = pendingItems + suscripcionesPendientes + completedItems + suscripcionesPagadas + gastosDiarios
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f €", totalGastos))
                                .foregroundColor(.red)
                                .bold()
                            
                            // Mostrar desglose resumido
                            Text("Pend: \(String(format: "%.2f", pendingItems + suscripcionesPendientes))€ + Pagado: \(String(format: "%.2f", completedItems + suscripcionesPagadas + gastosDiarios))€")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listSectionSeparator(.hidden)
                
                Section {
                    HStack {
                        Text("Total Beneficios")
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Calcular gastos totales para Previsión usando exactamente la misma lógica
                        // 1. Todos los items del listado Pendientes
                        let pendingItems = viewModel.expenses.filter { 
                            !$0.isCompleted && isInCurrentMonthOrBefore(date: $0.startDate)
                        }.reduce(0) { $0 + $1.amount }
                        
                        // 2. Gastos pendientes de otras cuentas
                        let suscripcionesPendientes = viewModel.pendingSubscriptions
                        
                        // 3. Todos los items del listado Completados
                        let completedItems = viewModel.expenses.filter { $0.isCompleted }.reduce(0) { $0 + $1.amount }
                        
                        // 4. Gastos pagados de otras cuentas
                        let suscripcionesPagadas = viewModel.completedSubscriptions
                        
                        // 5. Gastos diarios
                        let gastosDiarios = viewModel.gpTransactions.reduce(0) { $0 + $1.amount }
                        
                        // Sumar todos los componentes
                        let totalGastosFinal = pendingItems + suscripcionesPendientes + completedItems + suscripcionesPagadas + gastosDiarios
                        
                        // Cálculo de ingresos (mantener igual)
                        let ingresosPendientes = viewModel.pendingIncome
                        let ingresosCobrados = viewModel.completedIncome
                        // Verificar si se deben mostrar las propinas
                        let showTips = UserDefaults.standard.bool(forKey: "showTips")
                        let ingresosPropinas = (showTips && viewModel.findTipsTransaction() != nil) ?
                            viewModel.getCurrentMonthTipsTotal(tipTransaction: viewModel.findTipsTransaction()!) : 0
                        
                        let totalIngresosFinal = ingresosPendientes + ingresosCobrados + ingresosPropinas
                        
                        let beneficios = totalIngresosFinal - totalGastosFinal
                        Text(String(format: "%.2f €", beneficios))
                            .foregroundColor(.yellow)
                            .font(.title3)
                            .bold()
                    }
                }
                .listSectionSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
        .navigationTitle("Beneficios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Beneficios")
                        .font(.title2)
                        .bold()
                    Text("\(formatCurrentMonth()) \(formatCurrentYear())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Función auxiliar para determinar si una fecha está en el mes actual o anterior
    private func isInCurrentMonthOrBefore(date: Date?) -> Bool {
        // Si no hay fecha, siempre mostrar
        guard let startDate = date else {
            return true
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Determinar qué mes estamos mostrando (actual o siguiente)
        let referenceDate = viewModel.showNextMonth ? 
            calendar.date(byAdding: .month, value: 1, to: now)! : now
        
        // Obtener los componentes de año y mes de ambas fechas
        let startComponents = calendar.dateComponents([.year, .month], from: startDate)
        let referenceComponents = calendar.dateComponents([.year, .month], from: referenceDate)
        
        // La fecha está en un mes futuro si el año es mayor, o si el año es igual pero el mes es mayor
        let isInFutureMonth = startComponents.year! > referenceComponents.year! || 
                             (startComponents.year! == referenceComponents.year! && 
                              startComponents.month! > referenceComponents.month!)
        
        // Retornar verdadero si la fecha no está en un mes futuro
        return !isInFutureMonth
    }
} 