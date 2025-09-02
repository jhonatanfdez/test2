#!/bin/bash
 
# Ruta del archivo de salida (en el mismo directorio que el script)

OUTPUT_DIR="$(dirname "$0")"

OUTPUT_FILE="$OUTPUT_DIR/auditoria_oracle_linux_$(date +%Y%m%d_%H%M%S).log"
 
# Todo el contenido se muestra en pantalla y también se guarda en archivo

exec > >(tee -a "$OUTPUT_FILE") 2>&1
 
echo "========================================"

echo " AUDITORÍA DE SERVIDOR ORACLE LINUX "

echo " Fecha: $(date)"

echo " Archivo generado: $OUTPUT_FILE"

echo "========================================"
 
# 1. Servicios activos

echo -e "\n[1] Servicios activos:"

systemctl list-units --type=service --state=running
 
# 2. Versión del servidor

echo -e "\n[2] Versión del servidor:"

cat /etc/os-release
 
# 3. Carpetas con permisos 777

echo -e "\n[3] Carpetas con permisos 777:"

find / -type d -perm 0777 2>/dev/null
 
# 4. Puertos abiertos

echo -e "\n[4] Puertos abiertos:"

ss -tuln
 
# 5. Espacio en disco

echo -e "\n[5] Espacio en disco:"

df -h
 
# 6. Rendimiento de la memoria y swap

echo -e "\n[6] Rendimiento de memoria y configuración de swap:"

free -h

swapon --show
 
# 7. Usuarios locales

echo -e "\n[7] Usuarios locales en el sistema:"

cut -d: -f1 /etc/passwd
 
# 8. Grupos de usuarios

echo -e "\n[8] Grupos de usuarios:"

cut -d: -f1 /etc/group
 
# 9. Usuarios dentro de cada grupo

echo -e "\n[9] Usuarios en cada grupo:"

getent group | while IFS=: read -r group _ gid members; do

    echo "Grupo: $group"

    echo "Usuarios: $members"

    echo "-----------------------------"

done
 
# 10. Usuarios con privilegios sudo

echo -e "\n[10] Usuarios con privilegios de sudo:"

getent group sudo || getent group wheel
 
# 11. Listado de iptables

echo -e "\n[11] Reglas de iptables:"

iptables -L -n -v 2>/dev/null || echo "iptables no está disponible."
 
# 12. Configuración de firewall (firewalld si aplica)

echo -e "\n[12] Configuración del firewall:"

if systemctl is-active --quiet firewalld; then

    firewall-cmd --list-all

else

    echo "Firewalld no está activo."

fi
 
# 13. Actualizaciones pendientes

echo -e "\n[13] Actualizaciones pendientes:"

if dnf check-update; then

    echo "Se encontraron actualizaciones disponibles."

else

    echo "No se encontraron actualizaciones pendientes."

fi
 
# 14. Logs de auditoría (auditd)

echo -e "\n[14] Estado de logs de auditoría:"

systemctl is-active auditd && echo "Auditd está activo." || echo "Auditd NO está activo."
 
# 15. Parámetros de contraseña globales

echo -e "\n[15] Parámetros de contraseñas (login.defs):"

grep -E "PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE|PASS_MIN_LEN" /etc/login.defs
 
# 16. Parámetros de contraseñas por usuario (chage)

echo -e "\n[16] Parámetros de contraseñas por usuario (detalles con chage):"

for user in $(cut -d: -f1 /etc/passwd); do

    echo "---------------------------------------------"

    echo "Usuario: $user"

    chage -l $user 2>/dev/null

done
 
# 17. Usuarios genéricos o default

echo -e "\n[17] Usuarios genéricos o por defecto:"

grep -E "^(root|guest|test|user|admin)" /etc/passwd || echo "No se detectaron usuarios genéricos comunes."
 
# 18. Estado de usuarios (activos/inactivos)

echo -e "\n[18] Estado de usuarios (activos/inactivos):"

for user in $(cut -d: -f1 /etc/passwd); do

    passwd -S $user 2>/dev/null

done
 
echo -e "\n==================

 
