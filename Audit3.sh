
#!/bin/bash
 
echo "========================================"

echo " AUDITORÍA DE SERVIDOR ORACLE LINUX "

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

iptables -L -n -v
 
# 12. Configuración de firewall (firewalld si aplica)

echo -e "\n[12] Configuración del firewall:"

if systemctl is-active --quiet firewalld; then

    firewall-cmd --list-all

else

    echo "Firewalld no está activo."

fi
 
# 13. Actualizaciones pendientes

echo -e "\n[13] Actualizaciones pendientes:"

dnf check-update || echo "No se encontraron actualizaciones pendientes."
 
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

    chage -l $user

done
 
# 17. Usuarios genéricos o default

echo -e "\n[17] Usuarios genéricos o por defecto:"

grep -E "^(root|guest|test|user|admin)" /etc/passwd || echo "No se detectaron usuarios genéricos comunes."
 
#17.2 | Recorre todos los usuarios locales (UID >= 1000 para excluir cuentas de sistema)

printf "%-20s %-10s\n" "USUARIO" "ESTADO"

echo "------------------------------------"
 
for user in $(getent passwd | awk -F: '$3 >= 1 {print $1}'); do

    estado=$(sudo passwd -S "$user" 2>/dev/null | awk '{print $2}')

    case "$estado" in

        P)  status="ACTIVO" ;;

        L|LK) status="INACTIVO" ;;

        NP) status="INACTIVO (SIN CONTRASEÑA)" ;;

        *)  status="$estado" ;;

    esac

    printf "%-20s %-10s\n" "$user" "$status"

done
 
# 18. Estado de usuarios (activos/inactivos con tabla)

echo -e "\n[18] Estado de usuarios (activos/inactivos):"

printf "%-20s %-15s %-15s %-10s\n" "Usuario" "Estado" "Último cambio" "Activo?"

printf "%-20s %-15s %-15s %-10s\n" "-------------------" "-------------" "-------------" "-------"
 
while IFS= read -r user; do

    info=$(passwd -S "$user" 2>/dev/null)

    if [ -n "$info" ]; then

        username=$(echo "$info" | awk '{print $1}')

        status=$(echo "$info" | awk '{print $2}')

        last_change=$(echo "$info" | awk '{print $3}')

        # Traducir estado

        case "$status" in

            P) estado="Con contraseña" ; activo="Sí" ;;

            NP) estado="Sin contraseña" ; activo="No" ;;

            LK|L) estado="Bloqueado" ; activo="No" ;;

            *) estado="Desconocido" ; activo="?" ;;

        esac

        printf "%-20s %-15s %-15s %-10s\n" "$username" "$estado" "$last_change" "$activo"

    fi

done < <(cut -d: -f1 /etc/passwd)
 
echo -e "\n========================================"

echo " FIN DE AUDITORÍA "

echo "========================================"








 
