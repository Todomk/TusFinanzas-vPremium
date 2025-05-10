import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: FinanceViewModel
    @State private var notificationHour: Int
    @State private var notificationMinute: Int
    @State private var dayBeforeNotificationHour: Int
    @State private var dayBeforeNotificationMinute: Int
    @State private var showingPickerForSameDay = false
    @State private var showingPickerForDayBefore = false
    
    // Variables temporales para el modal
    @State private var tempNotificationHour: Int = 0
    @State private var tempNotificationMinute: Int = 0
    @State private var tempDayBeforeHour: Int = 0
    @State private var tempDayBeforeMinute: Int = 0

    init() {
        let hour = UserDefaults.standard.integer(forKey: "notificationHour")
        let minute = UserDefaults.standard.integer(forKey: "notificationMinute")
        let dayBeforeHour = UserDefaults.standard.integer(forKey: "dayBeforeNotificationHour")
        let dayBeforeMinute = UserDefaults.standard.integer(forKey: "dayBeforeNotificationMinute")
        _notificationHour = State(initialValue: hour >= 0 ? hour : 9)
        _notificationMinute = State(initialValue: minute >= 0 ? minute : 0)
        _dayBeforeNotificationHour = State(initialValue: dayBeforeHour >= 0 ? dayBeforeHour : 10)
        _dayBeforeNotificationMinute = State(initialValue: dayBeforeMinute >= 0 ? dayBeforeMinute : 0)
    }

    private func saveNotificationSettings() {
        print("[DEBUG] Guardando hora: \(notificationHour), minuto: \(notificationMinute), día anterior hora: \(dayBeforeNotificationHour), minuto: \(dayBeforeNotificationMinute)")
        // Guardar en UserDefaults
        UserDefaults.standard.set(notificationHour, forKey: "notificationHour")
        UserDefaults.standard.set(notificationMinute, forKey: "notificationMinute")
        UserDefaults.standard.set(dayBeforeNotificationHour, forKey: "dayBeforeNotificationHour")
        UserDefaults.standard.set(dayBeforeNotificationMinute, forKey: "dayBeforeNotificationMinute")
        
        // Forzar la sincronización inmediata
        UserDefaults.standard.synchronize()
        
        // Actualizar las notificaciones
        NotificationManager.shared.rescheduleAllNotifications()
        
        // Notificar al ViewModel para que actualice la vista de Configuración
        viewModel.objectWillChange.send()
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Mismo día:")
                Button(action: {
                    tempNotificationHour = notificationHour
                    tempNotificationMinute = notificationMinute
                    showingPickerForSameDay = true
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text(String(format: "%02d:%02d", notificationHour, notificationMinute))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .sheet(isPresented: $showingPickerForSameDay) {
                    HourMinutePickerView(hour: $tempNotificationHour, minute: $tempNotificationMinute, onDone: {
                        notificationHour = tempNotificationHour
                        notificationMinute = tempNotificationMinute
                        saveNotificationSettings()
                        showingPickerForSameDay = false
                    }, onCancel: {
                        showingPickerForSameDay = false
                    })
                }
                Text("Hora seleccionada: " + String(format: "%02d:%02d", notificationHour, notificationMinute))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Día anterior:")
                Button(action: {
                    tempDayBeforeHour = dayBeforeNotificationHour
                    tempDayBeforeMinute = dayBeforeNotificationMinute
                    showingPickerForDayBefore = true
                }) {
                    HStack {
                        Image(systemName: "clock")
                        Text(String(format: "%02d:%02d", dayBeforeNotificationHour, dayBeforeNotificationMinute))
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .sheet(isPresented: $showingPickerForDayBefore) {
                    HourMinutePickerView(hour: $tempDayBeforeHour, minute: $tempDayBeforeMinute, onDone: {
                        dayBeforeNotificationHour = tempDayBeforeHour
                        dayBeforeNotificationMinute = tempDayBeforeMinute
                        saveNotificationSettings()
                        showingPickerForDayBefore = false
                    }, onCancel: {
                        showingPickerForDayBefore = false
                    })
                }
                Text("Hora seleccionada: " + String(format: "%02d:%02d", dayBeforeNotificationHour, dayBeforeNotificationMinute))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            Text("Recibirás notificaciones el día del gasto y un día antes a la hora y minuto configurados.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .navigationTitle("Notificaciones")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    saveNotificationSettings()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Atrás")
                    }
                }
            }
        }
        .onDisappear {
            saveNotificationSettings()
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
            .environmentObject(FinanceViewModel())
    }
} 