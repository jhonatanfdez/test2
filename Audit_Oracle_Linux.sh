#!/bin/bash
# Auditoría básica para servidor Oracle Linux
# Guardar como auditoria.sh

echo "=========================================="
echo " AUDITORÍA DE SERVIDOR ORACLE LINUX"
echo " Fecha: $(date)"
echo "=========================================="

# 1. Información del sistema
echo -e "\n--- INFORMACIÓN DEL SISTEMA ---"
uname -a
cat /etc/os-release

# 2. Kernel y actualizaciones
echo -e "\n--- ACTUALIZACIONES DISPONIBLES ---"
yum check-update || dnf check-update

# 3. Servicios activos
echo -e "\n--- SERVICIOS ACTIVOS ---"
systemctl list-units --type=service --state=running

# 4. Servicios habilitados en arranque
echo -e "\n--- SERVICIOS EN ARRANQUE ---"
systemctl list-unit-files --type=service | grep enabled

# 5. Usuarios y grupos
echo -e "\n--- USUARIOS CON ACCESO AL SISTEMA ---"
cat /etc/passwd | grep "/bin/bash"

echo -e "\n--- USUARIOS CON PRIVILEGIOS SUDO ---"
getent group wheel
grep '^sudo' /etc/group

# 6. Configuración de red
echo -e "\n--- INTERFACES DE RED Y IP ---"
ip addr show

echo -e "\n--- PUERTOS ABIERTOS ---"
ss -tulnp

# 7. Firewall
echo -e "\n--- CONFIGURACIÓN FIREWALL ---"
firewall-cmd --list-all || iptables -L

# 8. SELinux
echo -e "\n--- ESTADO DE SELINUX ---"
getenforce
sestatus

# 9. Logs de seguridad recientes
echo -e "\n--- ÚLTIMOS 20 INTENTOS DE LOGIN FALLIDOS ---"
grep "Failed password" /var/log/secure | tail -n 20

# 10. Permisos críticos
echo -e "\n--- PERMISOS DE ARCHIVOS CRÍTICOS ---"
ls -l /etc/passwd
ls -l /etc/shadow
ls -l /etc/sudoers

# 11. Procesos críticos
echo -e "\n--- PROCESOS EN EJECUCIÓN ---"
ps aux --sort=-%mem | head -n 10

echo -e "\n=========================================="
echo " FIN DE AUDITORÍA"
echo "=========================================="
