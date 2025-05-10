#!/bin/bash

# Script para modificar la configuración de compilación de Swift en el proyecto TusFinanzas
# para evitar el problema "Target 'TusFinanzas' has Swift tasks not blocking downstream targets"

echo "Aplicando solución para el problema de Swift tasks not blocking downstream targets..."

# Añadir configuración al proyecto para desactivar la compilación en paralelo
xcodebuild -project TusFinanzas.xcodeproj -scheme TusFinanzas SWIFT_COMPILATION_MODE=wholemodule OTHER_SWIFT_FLAGS="-Xfrontend -enable-cross-module-incremental-build" clean build

echo "Solución aplicada. Intenta compilar el proyecto ahora." 