#!/bin/bash
# Script: estado_todos_usuarios.sh
# Objetivo: Mostrar todos los usuarios del sistema (sin importar el shell)
# y su estado de contraseña (ACTIVO / INACTIVO)

printf "%-25s %-15s\n" "USUARIO" "ESTADO"
echo "----------------------------------------------------"

# Recorre todos los usuarios en /etc/passwd
for user in $(cut -d: -f1 /etc/passwd); do
    # Obtiene el campo de estado crudo desde passwd -S
    estado_raw=$(sudo passwd -S "$user" 2>/dev/null | awk '{print $2}')

    # Normaliza a ACTIVO o INACTIVO
    case "$estado_raw" in
        P)   estado="ACTIVO" ;;
        L|LK|!!|!* ) estado="INACTIVO" ;;
        NP)  estado="INACTIVO (SIN CONTRASEÑA)" ;;
        "")  estado="DESCONOCIDO" ;;   # cuando passwd -S no devuelve nada
        *)   estado="OTRO: $estado_raw" ;;
    esac

    printf "%-25s %-15s\n" "$user" "$estado"
done
