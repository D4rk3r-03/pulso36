#!/bin/bash
# Pulso 36 · apaga la consola cuando la batería termina de cargar. Lo lanza acciones.sh con systemd-run como la
# unidad pulso36-apagar-al-cargar (corre como root y sigue aunque se cierre la app).
# «Llena» = entra muy poca corriente (< 200 mA) y además el cargador dice Full o el voltaje está en 4,15 V o más,
# tres minutos seguidos. El porcentaje no sirve (el medidor marca 100 % antes de estar llena) y el «Full» solo tampoco:
# en dArkOS llega a 4,13 V con 660 mA aún entrando, porque su tabla de batería da 100 % a 4,0 V. Red de seguridad:
# si lleva 90 minutos diciendo Full sin que baje la corriente, apaga igual.
# Si hay un juego o un port abierto, no apaga: espera a que se cierre (para no perder la partida).
# Si se desconecta el cargador, deja de vigilar sin apagar. Deja constancia en <conf>/apagar-al-cargar.log
CONF=${PULSO_CONF:-$(cd "$(dirname "$0")" && pwd)/conf/}
mkdir -p "$CONF"
LOG="$CONF/apagar-al-cargar.log"
anotar() { echo "$(date '+%F %T') $*" >> "$LOG"; }
leer() { cat "$1" 2> /dev/null; }

R=${PULSO_RAIZ:-}            # desarrollo: sensores falsos; PULSO_PASO (s entre lecturas) y PULSO_APAGAR (orden de apagar)
PASO=${PULSO_PASO:-60}; DORMIR=${PULSO_DORMIR:-$PASO}
B=""
for p in "$R"/sys/class/power_supply/*; do [ "$(leer "$p/type")" = Battery ] && { B=$p; break; }; done
[ -n "$B" ] && [ -r "$B/voltage_now" ] && [ -r "$B/current_now" ] || { anotar "no encuentro los sensores de la batería: no vigilo"; exit 1; }
cargador() { for p in "$R"/sys/class/power_supply/*; do [ "$(leer "$p/type")" != Battery ] && [ "$(leer "$p/online")" = 1 ] && return 0; done; return 1; }
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
seguidas=0; esperando=""; full=0
while true; do
  st=$(leer $B/status)
  mv=$(( $(leer $B/voltage_now || echo 0) / 1000 ))
  ma=$(( $(leer $B/current_now || echo 0) / 1000 )); ma=${ma#-}
  if ! cargador; then anotar "cargador desconectado ($mv mV): dejo de vigilar, no apago"; exit 0; fi
  if [ "$st" = Full ]; then full=$((full + 1)); else full=0; fi
  if { [ "$ma" -lt 200 ] && { [ "$st" = Full ] || [ "$mv" -ge 4150 ]; }; } || [ $((full * PASO)) -ge 5400 ]; then
    seguidas=$((seguidas + 1)); else seguidas=0; fi
  if [ "$seguidas" -ge 3 ]; then
    if j=$(jugando); then
      [ "$esperando" = "$j" ] || anotar "llena, pero «$j» está abierto: espero a que lo cierres"
      esperando=$j
    else
      anotar "llena ($st, $mv mV, $ma mA): apago la consola"
      sync; ${PULSO_APAGAR:-systemctl poweroff}; exit 0
    fi
  fi
  sleep "$DORMIR"
done
