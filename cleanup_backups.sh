#!/bin/bash

# Script para limpiar archivos de backup en TusFinanzas
# Autor: TusFinanzas Cleanup Script
# Fecha: $(date +%Y-%m-%d)

echo "🧹 Iniciando limpieza de archivos backup en TusFinanzas..."
echo ""

# Función para contar archivos
count_files() {
    find . -name "$1" -type f | wc -l
}

# Mostrar resumen de archivos a eliminar
echo "📊 RESUMEN DE ARCHIVOS BACKUP:"
echo "   - Archivos .backup-*: $(count_files "*.backup-*")"
echo "   - Archivos .bak: $(count_files "*.bak")"
echo "   - Archivos .v1.3.bak: $(count_files "*.v1.3.bak")"
echo "   - Archivos 2.bak: $(count_files "*2.bak")"
echo ""

# Crear backup de la lista antes de eliminar (por seguridad)
echo "📋 Creando lista de archivos que se van a eliminar..."
{
    echo "=== ARCHIVOS BACKUP ELIMINADOS $(date) ==="
    find . -name "*.backup-*" -type f
    find . -name "*.bak" -type f
    find . -name "*.v1.3.bak" -type f
    find . -name "*2.bak" -type f
    echo "=== FIN DE LISTA ==="
} > backup_files_deleted.log

echo "✅ Lista guardada en: backup_files_deleted.log"
echo ""

# Eliminar archivos .backup-* (con timestamp)
echo "🗑️  Eliminando archivos .backup-*..."
find . -name "*.backup-*" -type f -delete
echo "   ✅ Archivos .backup-* eliminados"

# Eliminar archivos .bak
echo "🗑️  Eliminando archivos .bak..."
find . -name "*.bak" -type f -delete
echo "   ✅ Archivos .bak eliminados"

# Eliminar archivos .v1.3.bak
echo "🗑️  Eliminando archivos .v1.3.bak..."
find . -name "*.v1.3.bak" -type f -delete
echo "   ✅ Archivos .v1.3.bak eliminados"

# Eliminar archivos con "2.bak"
echo "🗑️  Eliminando archivos *2.bak..."
find . -name "*2.bak" -type f -delete
echo "   ✅ Archivos *2.bak eliminados"

echo ""
echo "🎉 LIMPIEZA COMPLETADA!"
echo ""

# Verificar que se eliminaron
echo "📊 VERIFICACIÓN POST-LIMPIEZA:"
backup_count=$(find . -name "*.backup*" -type f | wc -l)
bak_count=$(find . -name "*.bak" -type f | wc -l)

if [ "$backup_count" -eq 0 ] && [ "$bak_count" -eq 0 ]; then
    echo "   ✅ Todos los archivos backup han sido eliminados correctamente"
else
    echo "   ⚠️  Algunos archivos backup aún existen:"
    echo "      - Archivos .backup*: $backup_count"
    echo "      - Archivos .bak: $bak_count"
fi

echo ""
echo "📝 RECOMENDACIONES:"
echo "   1. Revisa el archivo 'backup_files_deleted.log' para ver qué se eliminó"
echo "   2. Configura tu editor para no crear archivos .bak automáticamente"
echo "   3. Añade '*.bak' y '*.backup*' al .gitignore para evitar subirlos"
echo ""

# Verificar si existe .gitignore y sugerir añadir patrones
if [ -f ".gitignore" ]; then
    if ! grep -q "*.bak" .gitignore; then
        echo "💡 Sugerencia: Añadir patrones backup al .gitignore"
        echo "   Ejecuta: echo -e '\\n# Archivos de backup\\n*.bak\\n*.backup*\\n*.v1.*.bak' >> .gitignore"
    fi
else
    echo "💡 Sugerencia: Crear .gitignore con patrones backup"
    echo "   Ejecuta este script con 'create-gitignore' para crear uno"
fi

echo ""
echo "✨ Limpieza finalizada. Tu proyecto está más limpio ahora!"