#!/bin/bash
# usuarios_shadow_estado.sh
# Muestra usuario, UID, valor de shadow y estatus

printf "%-20s %-6s %-20s %-15s\n" "USUARIO" "UID" "SHADOW($2)" "ESTATUS"
echo "-----------------------------------------------------------------------"

while IFS=: read -r user _ uid _ _ _ _; do
  shadow2=$(sudo awk -F: -v u="$user" '$1==u{print $2}' /etc/shadow 2>/dev/null)

  if [[ "$shadow2" =~ ^\$ ]]; then
    estatus="ACTIVO"
  elif [[ -z "$shadow2" || "$shadow2" == "!" || "$shadow2" == "!!" || "$shadow2" == "*" ]]; then
    estatus="INACTIVO"
  else
    estatus="OTRO: $shadow2"
  fi

  printf "%-20s %-6s %-20s %-15s\n" "$user" "$uid" "${shadow2:-N/A}" "$estatus"
done < /etc/passwd
