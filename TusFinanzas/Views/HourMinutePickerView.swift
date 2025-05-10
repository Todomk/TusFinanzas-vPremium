import SwiftUI

struct HourMinutePickerView: UIViewControllerRepresentable {
    @Binding var hour: Int
    @Binding var minute: Int
    var onDone: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground

        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.selectRow(hour, inComponent: 0, animated: false)
        picker.selectRow(minute, inComponent: 1, animated: false)

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Confirmar", for: .normal)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.addTarget(context.coordinator, action: #selector(Coordinator.doneTapped), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancelar", for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(context.coordinator, action: #selector(Coordinator.cancelTapped), for: .touchUpInside)

        controller.view.addSubview(picker)
        controller.view.addSubview(doneButton)
        controller.view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            picker.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
            doneButton.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 16),
            doneButton.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor, constant: 60),
            cancelButton.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor, constant: -60)
        ])

        context.coordinator.picker = picker
        context.coordinator.parent = self
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No es necesario actualizar nada aquí
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: HourMinutePickerView!
        weak var picker: UIPickerView?

        init(_ parent: HourMinutePickerView) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            2
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? 24 : 60
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            String(format: "%02d", row)
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                parent.hour = row
            } else {
                parent.minute = row
            }
        }

        @objc func doneTapped() {
            parent.onDone?()
        }

        @objc func cancelTapped() {
            parent.onCancel?()
        }
    }
} 