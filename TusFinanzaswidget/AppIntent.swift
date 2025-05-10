//
//  AppIntent.swift
//  TusFinanzaswidget
//
//  Created by Angel Luis Rodriguez Malagon on 3/5/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuración" }
    static var description: IntentDescription { "Widget para monitorizar tus finanzas personales." }

    // Esta es una configuración básica que podría expandirse en el futuro
    @Parameter(title: "Mostrar propinas", default: true)
    var mostrarPropinas: Bool
}
