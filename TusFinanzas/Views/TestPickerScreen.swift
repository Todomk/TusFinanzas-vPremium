import SwiftUI

struct TestPickerScreen: View {
    @State private var hour = 9
    @State private var minute = 0
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Button("Seleccionar hora y minuto") {
                showPicker = true
            }
            .sheet(isPresented: $showPicker) {
                HourMinutePickerView(hour: $hour, minute: $minute, onDone: {
                    showPicker = false
                }, onCancel: {
                    showPicker = false
                })
            }
            Text("Seleccionado: " + String(format: "%02d:%02d", hour, minute))
                .font(.title2)
                .padding()
        }
        .navigationTitle("Prueba Picker")
    }
}

#Preview {
    NavigationView {
        TestPickerScreen()
    }
} 