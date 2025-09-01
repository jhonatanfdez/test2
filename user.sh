#!/bin/bash
# Script: estado_todos_usuarios_detallado.sh
# Muestra TODOS los usuarios con:
# - PASSWD_S (código crudo de `passwd -S`)
# - SHADOW($2) (campo 2 de /etc/shadow)
# - ESTATUS (interpretación)

printf "%-20s %-10s %-35s %-22s\n" "USUARIO" "PASSWD_S" "SHADOW(\$2)" "ESTATUS"
echo "--------------------------------------------------------------------------------------------------------------"

# Recorre todos los usuarios definidos en /etc/passwd
while IFS=: read -r user _ uid _ _ _ _; do
  # Código crudo desde passwd -S (columna 2)
  passwd_s=$(sudo passwd -S "$user" 2>/dev/null | awk '{print $2}')

  # Campo crudo del /etc/shadow (columna 2 -> hash/flags)
  shadow2=$(sudo awk -F: -v u="$user" '$1==u{print $2}' /etc/shadow 2>/dev/null)

  # Normalización del ESTATUS (preferimos /etc/shadow cuando exista)
  # Reglas:
  # - Si SHADOW empieza con '!' o es '!!' o '*': INACTIVO (bloqueado/sin login)
  # - Si SHADOW empieza con '$' (hash): ACTIVO
  # - Si SHADOW vacío: INACTIVO (SIN CONTRASEÑA)
  # - Si no hay SHADOW, usar PASSWD_S:
  #   P=ACTIVO; L/LK/!!/*=INACTIVO; NP=INACTIVO (SIN CONTRASEÑA)
  estatus="DESCONOCIDO"

  if [[ -n "$shadow2" ]]; then
    if [[ "$shadow2" == '!'* || "$shadow2" == '!!' || "$shadow2" == '*' ]]; then
      estatus="INACTIVO"
    elif [[ "$shadow2" == \$* ]]; then
      estatus="ACTIVO"
    elif [[ -z "$shadow2" ]]; then
      estatus="INACTIVO (SIN CONTRASEÑA)"
    else
      # Casos raros (ej. '!*', '!' solo, etc.)
      case "$shadow2" in
        '!*'|'!'|*'!*'*) estatus="INACTIVO" ;;
        *) estatus="OTRO ($shadow2)" ;;
      esac
    fi
  else
    # Sin acceso a shadow o no existe la entrada: usar passwd -S
    case "$passwd_s" in
      P)  estatus="ACTIVO" ;;
      L|LK|!!|'*') estatus="INACTIVO" ;;
      NP) estatus="INACTIVO (SIN CONTRASEÑA)" ;;
      "") estatus="DESCONOCIDO" ;;
      *)  estatus="OTRO ($passwd_s)" ;;
    esac
  fi

  printf "%-20s %-10s %-35s %-22s\n" "$user" "${passwd_s:-N/A}" "${shadow2:-N/A}" "$estatus"
done < /etc/passwd







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


