#!/bin/bash
# Acciones de mentira para probar en un PC: no cambian nada, solo responden como acciones.sh.
case "$1" in
  internet) sleep 0.6; echo "PASO|1|ok|responde · 4 ms"; sleep 0.6; echo "PASO|2|ok|sí · 38 ms"; sleep 0.5; echo "PASO|3|ok|sí"; sleep 1; echo "PASO|4|ok|sí · 412 ms" ;;
  modo) sleep 0.3; echo "Modo del procesador: $2" ;;
  zram) sleep 0.8; echo "ZRam: $2 $3" ;;
  registro) sleep 0.5; echo "Registro de batería: $2" ;;
  servicios) sleep 0.8; echo "Servicios: $2" ;;
  banda) sleep 0.8; echo "«MiWifi»: banda $2" ;;
  cerrar) sleep 1; echo "Cerrado: $3" ;;
  energia) sleep 0.5; echo "Energía: $2" ;;
  ocupa) echo "TOTAL=$(wc -l < "$(dirname "$0")/du.txt")"; while read -r l; do echo "$l"; sleep 0.03; done < "$(dirname "$0")/du.txt" ;;
  *) exit 2 ;;
esac
