
#!/bin/bash
# Script: estado_todos_usuarios_detallado.sh
# Muestra TODOS los usuarios con:
# - PASSWD_S (código crudo de `passwd -S`)
# - SHADOW($2) (campo 2 de /etc/shadow)
# - ESTATUS (interpretación)

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

 





printf "Cambio"
printf "=========="

printf "Primera línea\nSegunda línea\n"

# Cruza /etc/passwd (para nombres) y /etc/shadow (estatus)
while IFS=: read -r user _ uid _ _ _ _; do
  shadow2=$(sudo awk -F: -v u="$user" '$1==u{print $2}' /etc/shadow)
  # Interpretación simple
  if [[ "$shadow2" =~ ^\$ ]]; then st="ACTIVO"
  elif [[ -z "$shadow2" || "$shadow2" == "!" || "$shadow2" == "!!" || "$shadow2" == "*" || "$shadow2" == NP ]]; then st="INACTIVO"
  else st="OTRO: $shadow2"; fi
  printf "%-20s %-30s %-12s\n" "$user" "${shadow2:-N/A}" "$st"
done < /etc/passwd

