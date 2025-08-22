#!/bin/bash
# auditoria_oracle_linux.sh
# Script de auditoría básica para servidores Oracle Linux
# Autor: ChatGPT
# Uso: ./auditoria_oracle_linux.sh > resultado_auditoria.txt

echo "===================================="
echo " AUDITORÍA DE SERVIDOR ORACLE LINUX "
echo " Fecha: $(date)"
echo "===================================="
echo

# Información del sistema
echo ">>> INFORMACIÓN DEL SISTEMA"
uname -a
cat /etc/os-release
uptime
echo

# Estado de actualizaciones
echo ">>> ACTUALIZACIONES PENDIENTES"
if command -v dnf >/dev/null 2>&1; then
    dnf check-update || echo "No se pudo verificar actualizaciones."
elif command -v yum >/dev/null 2>&1; then
    yum check-update || echo "No se pudo verificar actualizaciones."
fi
echo

# Usuarios y grupos
echo ">>> USUARIOS Y GRUPOS"
echo "Usuarios en el sistema:"
cut -d: -f1 /etc/passwd
echo
echo "Usuarios con acceso a shell:"
grep -E "sh$" /etc/passwd
echo
echo "Grupos:"
cut -d: -f1 /etc/group
echo

# Revisar sudoers
echo ">>> USUARIOS CON PRIVILEGIOS DE SUDO"
grep -E '^[^#].*ALL' /etc/sudoers /etc/sudoers.d/* 2>/dev/null
echo

# Configuración de contraseñas
echo ">>> POLÍTICAS DE CONTRASEÑAS"
cat /etc/login.defs | grep -E 'PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE'
echo

# Servicios activos
echo ">>> SERVICIOS ACTIVOS"
systemctl list-units --type=service --state=running
echo

# Puertos en escucha
echo ">>> PUERTOS ABIERTOS"
ss -tuln
echo

# Reglas de firewall
echo ">>> REGLAS DE FIREWALL"
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --list-all
elif command -v iptables >/dev/null 2>&1; then
    iptables -L -n -v
else
    echo "No se encontró firewall-cmd ni iptables."
fi
echo

# SELinux
echo ">>> ESTADO DE SELINUX"
getenforce 2>/dev/null || echo "SELinux no instalado"
echo

# Auditoría de logs críticos
echo ">>> LOGS DE SEGURIDAD RECIENTES"
journalctl -p 3 -xb | tail -n 20
echo
echo "Últimos intentos de inicio de sesión fallidos:"
lastb | head -n 10
echo

# Espacio en disco
echo ">>> ESPACIO EN DISCO"
df -hT
echo

# Permisos sospechosos
echo ">>> ARCHIVOS CON PERMISOS SUID/GUID"
find / -perm /6000 -type f 2>/dev/null
echo

echo "===================================="
echo " FIN DE AUDITORÍA "
echo "===================================="