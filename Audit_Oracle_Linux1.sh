#!/usr/bin/env bash
# Oracle Linux Audit Script
# Cubre: usuarios/sudo, cuentas genéricas, políticas de contraseña, per-user aging,
# permisos 777, actualizaciones pendientes, firewall/iptables, auditd, puertos/servicios,
# SELinux/AppArmor, SSH, cron, integridad de binarios (rpm -Va/AIDE), NTP, kernel modules,
# versión SO, disco, memoria/swap.
 
set -u
IFS=$'\n\t'
 
# ---------- Utilidades ----------
timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
host="$(hostname -f 2>/dev/null || hostname)"
os_id="$(. /etc/os-release 2>/dev/null; echo "${ID:-unknown}")"
os_ver="$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-unknown}")"
outdir="audit_${host}_${timestamp}"
rep="${outdir}/reporte.txt"
mkdir -p "${outdir}/evidencia"
 
log() { echo "[$(date +'%H:%M:%S')] $*" | tee -a "${rep}"; }
hdr() { printf "\n==== %s ====\n" "$*" | tee -a "${rep}"; }
run() {
  local title="$1"; shift
  hdr "${title}"
  {
    echo "# CMD: $*"
    "$@" 2>&1 || echo "[WARN] Falló el comando o no está disponible."
  } | tee -a "${rep}"
}
 
need_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Debe ejecutar como root (sudo)." >&2
    exit 1
  fi
}
 
have() { command -v "$1" >/dev/null 2>&1; }
 
save_file() { # save output to evidence file and summarize path in report
  local filepath="$1"; shift
  printf "\n(Evidencia: %s)\n" "${filepath}" | tee -a "${rep}"
}
 
# ---------- Inicio ----------
need_root
echo "Oracle Linux Audit - Host: ${host} - SO: ${os_id} ${os_ver}" | tee "${rep}"
echo "Salida principal: ${rep}"
echo "Carpeta de evidencias: ${outdir}/evidencia" | tee -a "${rep}"
 
# ---------- 1) Versión del servidor / kernel ----------
hdr "Información del Sistema"
{ 
  echo "# /etc/os-release"
  cat /etc/os-release 2>/dev/null || true
  echo
  echo "# uname -a"
  uname -a
  echo
  echo "# dnf/yum versión"
  (have dnf && dnf --version) || (have yum && yum --version) || echo "dnf/yum no disponible"
} | tee -a "${rep}"
 
# ---------- 2) Usuarios y privilegios ----------
hdr "Usuarios locales"
getent passwd | tee "${outdir}/evidencia/usuarios.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/usuarios.txt"
 
hdr "Grupos y miembros"
getent group | tee "${outdir}/evidencia/grupos.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/grupos.txt"
 
hdr "Usuarios dentro de cada grupo (resumen)"
cut -d: -f1 /etc/group | while read -r g; do
  echo "Grupo: $g"
  getent group "$g" | awk -F: '{print "Miembros: " ($4==""?"(ninguno)":$4)}'
done | tee -a "${rep}"
 
hdr "Usuarios con privilegios de sudo"
{
  echo "# Archivo sudoers principal"
  grep -v '^\s*#' /etc/sudoers 2>/dev/null | sed '/^\s*$/d' || true
  echo
  echo "# Archivos en /etc/sudoers.d/"
  if [[ -d /etc/sudoers.d ]]; then
    for f in /etc/sudoers.d/*; do
      [[ -f "$f" ]] || continue
      echo "== $f =="
      grep -v '^\s*#' "$f" | sed '/^\s*$/d'
    done
  else
    echo "No existe /etc/sudoers.d"
  fi
  echo
  echo "# Miembros del grupo wheel (si aplica)"
  getent group wheel || true
} | tee "${outdir}/evidencia/sudoers.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/sudoers.txt"
 
hdr "Usuarios genéricos / por defecto potencialmente sensibles"
awk -F: '($3<1000 && $1!="root"){print $0} /nologin|false/{next}' /etc/passwd | tee -a "${rep}" || true
echo "Sugerencia: verificar también cuentas de aplicación con shells válidos." | tee -a "${rep}"
 
# ---------- 3) Políticas de contraseña ----------
hdr "Parámetros de contraseña (globales)"
{
  echo "# /etc/login.defs (extracto relevante)"
  egrep -i 'PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE' /etc/login.defs 2>/dev/null || echo "No se encontraron parámetros"
  echo
  echo "# PAM password policy (password-auth, system-auth si existen)"
  for f in /etc/pam.d/password-auth /etc/pam.d/system-auth; do
    [[ -f "$f" ]] && { echo "== $f =="; grep -E 'pam_(pwquality|cracklib|unix|faillock)' "$f"; echo; }
  done
} | tee -a "${rep}"
 
hdr "Parámetros de contraseña por usuario (aging)"
{
  echo "# chage -l <usuario> (usuarios UID>=1000, excluye nologin)"
  awk -F: '($3>=1000 && $7!~/(nologin|false)$/){print $1}' /etc/passwd | while read -r u; do
    echo "---- $u ----"
    chage -l "$u" || true
  done
} | tee "${outdir}/evidencia/aging_usuarios.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/aging_usuarios.txt"
 
# ---------- 4) Permisos 777 ----------
hdr "Directorios con permisos 777 (esto es crítico)"
{
  # Limitar a algunos paths comunes para acotar tiempo
  for base in / /var /opt /home /tmp /usr/local; do
    [[ -d "$base" ]] || continue
    echo "Escaneando: $base"
    find "$base" -xdev -type d -perm -000777 2>/dev/null
  done
} | tee "${outdir}/evidencia/permisos_777.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/permisos_777.txt"
 
# ---------- 5) Actualizaciones pendientes ----------
hdr "Actualizaciones pendientes del SO"
{
  if have dnf; then
    echo "# dnf check-update"
    dnf -q check-update || true
    echo
    echo "# dnf updateinfo summary"
    dnf updateinfo summary -q || true
  elif have yum; then
    echo "# yum check-update"
    yum -q check-update || true
  else
    echo "dnf/yum no disponibles."
  fi
} | tee "${outdir}/evidencia/updates.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/updates.txt"
 
# ---------- 6) Firewall / iptables ----------
hdr "Configuración de firewalls"
{
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "# firewalld activo"
    firewall-cmd --state
    echo
    echo "# Zonas"
    firewall-cmd --get-active-zones
    for z in $(firewall-cmd --get-active-zones | awk 'NR%2==1'); do
      echo "== Zona: $z =="
      firewall-cmd --zone="$z" --list-all
      echo
    done
  else
    echo "firewalld no activo. Revisando iptables/legacy..."
    if have iptables; then
      echo "# iptables -S"
      iptables -S || true
      echo
      echo "# iptables -L -n -v"
      iptables -L -n -v || true
    else
      echo "iptables no disponible."
    fi
  fi
} | tee "${outdir}/evidencia/firewall.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/firewall.txt"
 
hdr "Listado de IPtables (si aplica)"
(if have iptables; then iptables -S || true; else echo "iptables no disponible"; fi) \
  | tee "${outdir}/evidencia/iptables_rules.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/iptables_rules.txt"
 
# ---------- 7) Logs de auditoría ----------
hdr "Estado de auditd (logs de auditoría)"
{
  systemctl status auditd 2>&1 || echo "auditd no instalado o inactivo."
  echo
  [[ -f /etc/audit/auditd.conf ]] && { echo "# auditd.conf extracto"; egrep -v '^\s*#' /etc/audit/auditd.conf | sed '/^\s*$/d'; }
  [[ -f /etc/audit/rules.d/audit.rules ]] && { echo; echo "# audit.rules (rules.d)"; egrep -v '^\s*#' /etc/audit/rules.d/audit.rules | sed '/^\s*$/d'; }
} | tee "${outdir}/evidencia/auditd.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/auditd.txt"
 
# ---------- 8) Puertos abiertos / Servicios ----------
hdr "Puertos abiertos (escucha local)"
{
  if have ss; then
    ss -tulpen || ss -tuln
  else
    netstat -tulpen 2>/dev/null || netstat -tuln 2>/dev/null || echo "ss/netstat no disponibles"
  fi
} | tee "${outdir}/evidencia/puertos_abiertos.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/puertos_abiertos.txt"
 
hdr "Servicios activos"
{
  systemctl list-units --type=service --state=running
  echo
  echo "# Servicios habilitados al arranque"
  systemctl list-unit-files --type=service | egrep 'enabled|disabled' | sort
} | tee "${outdir}/evidencia/servicios.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/servicios.txt"
 
# ---------- 9) SELinux / AppArmor ----------
hdr "SELinux / AppArmor"
{
  if have sestatus; then
    echo "# sestatus"
    sestatus
    echo
    echo "# Configuración /etc/selinux/config (si existe)"
    [[ -f /etc/selinux/config ]] && egrep -v '^\s*#' /etc/selinux/config | sed '/^\s*$/d'
  else
    echo "sestatus no disponible. (En Oracle Linux normalmente hay SELinux)."
  fi
  if have aa-status; then
    echo; echo "# AppArmor status"
    aa-status
  else
    echo "AppArmor no aplicado en este sistema."
  fi
} | tee "${outdir}/evidencia/selinux_apparmor.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/selinux_apparmor.txt"
 
# ---------- 10) SSH ----------
hdr "Configuración de SSH (endurecimiento)"
{
  cfg="/etc/ssh/sshd_config"
  if [[ -f "$cfg" ]]; then
    echo "# Parámetros clave"
    egrep -i '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|PermitEmptyPasswords|ChallengeResponseAuthentication|UsePAM|AllowUsers|AllowGroups|Protocol|MaxAuthTries|LoginGraceTime)\b' "$cfg" || echo "No se hallaron parámetros clave (ver archivo completo)."
    echo
    echo "# Archivo completo (comentarios removidos)"
    egrep -v '^\s*#' "$cfg" | sed '/^\s*$/d'
  else
    echo "No existe ${cfg}"
  fi
} | tee "${outdir}/evidencia/ssh_config.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/ssh_config.txt"
 
# ---------- 11) Cron / tareas programadas ----------
hdr "Cron jobs y tareas programadas"
{
  echo "# /etc/crontab"
  [[ -f /etc/crontab ]] && cat /etc/crontab || echo "No existe /etc/crontab"
  echo
  for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
    [[ -d "$d" ]] && { echo "## $d"; ls -l "$d"; echo; }
  done
  echo "# Crons por usuario (UID>=1000)"
  awk -F: '($3>=1000 && $7!~/(nologin|false)$/){print $1}' /etc/passwd | while read -r u; do
    echo "-- crontab de $u --"
    crontab -u "$u" -l 2>&1 || echo "(sin crontab)"
  done
} | tee "${outdir}/evidencia/cron.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/cron.txt"
 
# ---------- 12) Integridad de binarios ----------
hdr "Integridad de binarios críticos"
{
  if have rpm; then
    echo "# rpm -Va (verificación de integridad de paquetes instalados)"
    echo "(Puede tardar. Salidas con códigos como 'S.5....T' indican diferencias)"
    rpm -Va 2>/dev/null | head -n 500
    echo "... (salida truncada a 500 líneas, ver archivo completo en evidencia)"
    rpm -Va 2>/dev/null > "${outdir}/evidencia/rpm_verify_full.txt" || true
    echo "Evidencia completa en: evidencia/rpm_verify_full.txt"
  else
    echo "rpm no disponible. Considere instalar AIDE: dnf install -y aide"
  fi
} | tee -a "${rep}"
 
# ---------- 13) Sincronización de tiempo (NTP) ----------
hdr "Sincronización de tiempo (NTP/chrony/systemd-timesyncd)"
{
  timedatectl 2>&1 || echo "timedatectl no disponible"
  echo
  if systemctl is-active --quiet chronyd 2>/dev/null; then
    echo "# chrony sources"
    (have chronyc && chronyc sources -v) || echo "chronyc no disponible"
  fi
} | tee "${outdir}/evidencia/ntp.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/ntp.txt"
 
# ---------- 14) Kernel modules ----------
hdr "Módulos de kernel cargados"
(lsmod 2>/dev/null || echo "lsmod no disponible") | tee "${outdir}/evidencia/lsmod.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/lsmod.txt"
 
# ---------- 15) Red / exposición ----------
hdr "Interfaces e IPs"
(ip addr show 2>/dev/null || ifconfig -a 2>/dev/null || echo "ip/ifconfig no disponibles") \
  | tee "${outdir}/evidencia/red_interfaces.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/red_interfaces.txt"
 
# ---------- 16) Disco, memoria, swap, rendimiento ----------
hdr "Espacio en disco"
df -hT | tee "${outdir}/evidencia/disco_df.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/disco_df.txt"
 
hdr "Uso de inodos"
df -hi | tee "${outdir}/evidencia/disco_inodos.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/disco_inodos.txt"
 
hdr "Memoria y swap"
{
  free -h
  echo
  echo "# vmstat 1 5"
  (have vmstat && vmstat 1 5) || echo "vmstat no disponible"
  echo
  echo "# swappiness"
  sysctl vm.swappiness 2>/dev/null || cat /proc/sys/vm/swappiness 2>/dev/null || echo "No se pudo leer swappiness"
} | tee "${outdir}/evidencia/mem_swap.txt" | tee -a "${rep}"
save_file "${outdir}/evidencia/mem_swap.txt"
 
# ---------- 17) Resumen rápido ----------
hdr "Resumen rápido (para priorización)"
{
  echo "- Usuarios con sudo: $(grep -E '^\s*%?wheel|ALL=\(ALL\)' -r /etc/sudoers /etc/sudoers.d 2>/dev/null | wc -l)"
  echo "- Directorios 777: $(grep -v '^Escaneando' "${outdir}/evidencia/permisos_777.txt" | sed '/^\s*$/d' | wc -l)"
  echo "- Puertos escuchando: $( (have ss && ss -tuln | tail -n +2 | wc -l) || (netstat -tuln 2>/dev/null | tail -n +3 | wc -l) || echo 0 )"
  echo "- Actualizaciones pendientes (ver evidencia/updates.txt)."
  echo "- SELinux: $( (have sestatus && sestatus | awk -F: '/status:/ {print $2}' | xargs) || echo 'Desconocido')"
  echo "- auditd: $(systemctl is-active auditd 2>/dev/null || echo 'no instalado')"
} | tee -a "${rep}"
 
echo
log "Auditoría finalizada. Revise: ${rep} y la carpeta ${outdir}/evidencia"
 
-----------------------------------------------------------------------
