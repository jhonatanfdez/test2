#!/bin/bash
# Script: estado_todos_usuarios_detallado.sh
# Muestra TODOS los usuarios con:
# - PASSWD_S (código crudo de `passwd -S`)
# - SHADOW($2) (campo 2 de /etc/shadow)
# - ESTATUS (interpretación)


printf "otro script"
printf "=========="

# Cruza /etc/passwd (para nombres) y /etc/shadow (estatus)
while IFS=: read -r user _ uid _ _ _ _; do
  shadow2=$(sudo awk -F: -v u="$user" '$1==u{print $2}' /etc/shadow)
  # Interpretación simple
  if [[ "$shadow2" =~ ^\$ ]]; then st="ACTIVO"
  elif [[ -z "$shadow2" || "$shadow2" == "!" || "$shadow2" == "!!" || "$shadow2" == "*" || "$shadow2" == NP ]]; then st="INACTIVO"
  else st="OTRO: $shadow2"; fi
  printf "%-20s %-30s %-12s\n" "$user" "${shadow2:-N/A}" "$st"
done < /etc/passwd


