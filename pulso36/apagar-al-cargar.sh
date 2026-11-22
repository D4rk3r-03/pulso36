#!/bin/bash
# Pulso 36 · apaga la consola cuando la batería termina de cargar. Lo lanza acciones.sh con systemd-run como la
# unidad pulso36-apagar-al-cargar (corre como root y sigue aunque se cierre la app).
# «Llena» = el cargador dice Full, o el voltaje ya está arriba de 4,15 V y entra muy poca corriente (< 200 mA),
# tres minutos seguidos (el porcentaje no sirve: el medidor suele marcar 100 % antes de estar llena).
# Si hay un juego o un port abierto, no apaga: espera a que se cierre (para no perder la partida).
# Si se desconecta el cargador, deja de vigilar sin apagar. Deja constancia en <conf>/apagar-al-cargar.log
CONF=${PULSO_CONF:-$(cd "$(dirname "$0")" && pwd)/conf/}
mkdir -p "$CONF"
LOG="$CONF/apagar-al-cargar.log"
anotar() { echo "$(date '+%F %T') $*" >> "$LOG"; }
leer() { cat "$1" 2> /dev/null; }

B=""
for p in /sys/class/power_supply/*; do [ "$(leer "$p/type")" = Battery ] && { B=$p; break; }; done
[ -n "$B" ] && [ -r "$B/voltage_now" ] && [ -r "$B/current_now" ] || { anotar "no encuentro los sensores de la batería: no vigilo"; exit 1; }
cargador() { for p in /sys/class/power_supply/*; do [ "$(leer "$p/type")" != Battery ] && [ "$(leer "$p/online")" = 1 ] && return 0; done; return 1; }
# un juego abierto: RetroArch, o un port (menos Pulso 36 y PortMaster)
jugando() {
  pgrep -x retroarch > /dev/null && { echo retroarch; return 0; }
  local p c
  for p in /proc/[0-9]*; do
    c=$(readlink "$p/cwd" 2> /dev/null) || continue
    case "$c" in */ports/pulso36*|*/ports/PortMaster*) ;; */ports/?*) c=${c##*/ports/}; echo "${c%%/*}"; return 0 ;; esac
  done
  return 1
}

anotar "vigilando: se apagará al terminar de cargar"
seguidas=0; esperando=""
while true; do
  st=$(leer $B/status)
  mv=$(( $(leer $B/voltage_now || echo 0) / 1000 ))
  ma=$(( $(leer $B/current_now || echo 0) / 1000 )); ma=${ma#-}
  if ! cargador; then anotar "cargador desconectado ($mv mV): dejo de vigilar, no apago"; exit 0; fi
  if [ "$st" = Full ] || { [ "$mv" -ge 4150 ] && [ "$ma" -lt 200 ]; }; then seguidas=$((seguidas + 1)); else seguidas=0; fi
  if [ "$seguidas" -ge 3 ]; then
    if j=$(jugando); then
      [ "$esperando" = "$j" ] || anotar "llena, pero «$j» está abierto: espero a que lo cierres"
      esperando=$j
    else
      anotar "llena ($st, $mv mV, $ma mA): apago la consola"
      sync; systemctl poweroff; exit 0
    fi
  fi
  sleep 60
done
