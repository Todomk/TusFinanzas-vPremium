#!/bin/bash

# Script para solucionar el problema de dependencia circular en el proyecto TusFinanzas

echo "Configurando los ajustes para evitar el problema de Swift tasks not blocking..."

# 1. Primero, limpiar proyecto
xcodebuild clean -project TusFinanzas.xcodeproj -alltargets

# 2. Modificar el modo de compilación de Swift para evitar problemas
# Esto fuerza a que Swift espere a que se completen las tareas antes de continuar
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelTargetBuilds -bool NO

# 3. Crear un archivo de configuración temporal para la compilación
cat > swift_fix.xcconfig << EOF
// Configuración para evitar problemas de Swift tasks not blocking
SWIFT_ENABLE_BATCH_MODE = NO
OTHER_SWIFT_FLAGS = -Xfrontend -enable-cross-module-incremental-build -Xfrontend -disable-cross-module-incremental-build -Xfrontend -enable-batch-mode
EOF

echo "Configuración aplicada."
echo ""
echo "Para solucionar permanentemente este problema, por favor:"
echo "1. Abre el proyecto en Xcode"
echo "2. Selecciona el target TusFinanzaswidgetExtension"
echo "3. Ve a Build Phases -> Target Dependencies"
echo "4. Elimina la dependencia a TusFinanzas"
echo "5. Limpie y reconstruya el proyecto"
echo ""
echo "Estos pasos deben resolver el problema de 'Target has Swift tasks not blocking downstream targets'." 