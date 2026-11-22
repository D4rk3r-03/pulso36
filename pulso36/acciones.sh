#!/bin/bash
# Pulso 36: todo lo que cambia algo del sistema. La app lo llama y muestra la última línea que imprime.
#   modo <governor>                       zram on|off|tam <MB>|instalar|desinstalar
#   registro on|off|instalar <dir>|desinstalar
#   internet                              servicios ssh|apagar
#   banda 24|auto                         cerrar <pid> <nombre>
#   energia menu|reiniciar|apagar|vigilar|cancelar                        ocupa
# Códigos de salida: 0 bien · 1 falló · 2 orden no válida · 3 falta el servicio · 77 sin permisos de administrador
# Rutas: la carpeta de este script, la de los juegos (/roms o /roms2) y la de ajustes y log (las da el lanzador).
CASA=$(cd "$(dirname "$0")" && pwd)
ROMS=${PULSO_ROMS:-/roms}
CONF=${PULSO_CONF:-$CASA/conf/}
SIS="$CASA/sistema"

# Ejecutar como administrador: directo si ya somos root, con sudo sin contraseña si se puede; si no, se avisa.
priv() {
  if [ "$(id -u)" = 0 ]; then "$@"
  elif sudo -n true 2> /dev/null; then sudo -n "$@"
  else echo "Esta consola no deja cambiar el sistema (falta sudo sin contraseña)"; exit 77; fi
}
existe() { systemctl cat "$1" > /dev/null 2>&1; }
# la primera interfaz inalámbrica (iw no está en todos los sistemas)
wifi_if() { for n in /sys/class/net/*/wireless; do [ -e "$n" ] && { basename "$(dirname "$n")"; return; }; done; }
cargador() {
  for p in /sys/class/power_supply/*; do
    [ "$(cat "$p/type" 2> /dev/null)" != Battery ] && [ "$(cat "$p/online" 2> /dev/null)" = 1 ] && return 0
  done; return 1
}

case "$1" in
  modo)
    disp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2> /dev/null)
    case " $disp " in *" $2 "*) ;; *) echo "Este sistema no tiene el modo $2"; exit 2 ;; esac
    for p in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do echo "$2" | priv tee "$p" > /dev/null || exit 1; done
    echo "Modo del procesador: $2" ;;

  zram)     # la ZRam propia de Pulso 36 (solo se ofrece si el sistema no trae otra)
    U=pulso36-zram
    case "$2" in
      instalar)
        [ -d /sys/block/zram0 ] || modinfo zram > /dev/null 2>&1 || { echo "Este sistema no tiene zram"; exit 1; }
        priv install -m 755 -o root -g root "$SIS/pulso36-zram" /usr/local/bin/pulso36-zram || exit 1
        priv install -m 644 -o root -g root "$SIS/pulso36-zram.service" /etc/systemd/system/pulso36-zram.service || exit 1
        [ -f /etc/default/pulso36-zram ] || echo "TAMANO_MB=512" | priv tee /etc/default/pulso36-zram > /dev/null
        priv systemctl daemon-reload
        priv systemctl enable --now $U > /dev/null 2>&1 && echo "ZRam instalada y encendida (también al arrancar)" ;;
      desinstalar)
        existe $U || { echo "La ZRam de Pulso 36 no está instalada"; exit 3; }
        priv systemctl disable --now $U > /dev/null 2>&1
        priv rm -f /etc/systemd/system/pulso36-zram.service /usr/local/bin/pulso36-zram /etc/default/pulso36-zram
        priv systemctl daemon-reload
        echo "ZRam de Pulso 36 desinstalada" ;;
      on|off|tam)
        existe $U || { echo "La ZRam de Pulso 36 no está instalada"; exit 3; }
        case "$2" in
          on)  priv systemctl enable $U > /dev/null 2>&1; priv systemctl restart $U && echo "ZRam encendida (también al arrancar)" ;;
          off) priv systemctl disable $U > /dev/null 2>&1; priv systemctl stop $U && echo "ZRam apagada" ;;
          tam)
            case "$3" in 256|512|768) ;; *) echo "Tamaño no válido"; exit 2;; esac
            echo "TAMANO_MB=$3" | priv tee /etc/default/pulso36-zram > /dev/null || exit 1
            if grep -q zram0 /proc/swaps; then priv systemctl restart $U || exit 1; fi
            echo "ZRam: $3 MB" ;;
        esac ;;
      *) exit 2 ;;
    esac ;;

  registro) # una línea por minuto en el CSV del registro, también al arrancar (pulso36-registro.service)
    U=pulso36-registro
    case "$2" in
      instalar)
        dir="${3%/}"; [ -n "$dir" ] || { echo "Falta la carpeta del registro"; exit 2; }
        mkdir -p "$dir" 2> /dev/null || priv mkdir -p "$dir" || exit 1
        priv install -m 755 -o root -g root "$SIS/pulso36-registro" /usr/local/bin/pulso36-registro || exit 1
        priv install -m 644 -o root -g root "$SIS/pulso36-registro.service" /etc/systemd/system/pulso36-registro.service || exit 1
        printf 'DIR=%s\n' "$dir" | priv tee /etc/default/pulso36-registro > /dev/null || exit 1
        priv systemctl daemon-reload
        priv systemctl enable --now $U > /dev/null 2>&1 && echo "Registro de batería instalado y encendido" ;;
      desinstalar)
        existe $U || { echo "El registro de Pulso 36 no está instalado"; exit 3; }
        priv systemctl disable --now $U > /dev/null 2>&1
        priv rm -f /etc/systemd/system/pulso36-registro.service /usr/local/bin/pulso36-registro /etc/default/pulso36-registro
        priv systemctl daemon-reload
        echo "Registro desinstalado (lo ya anotado se queda)" ;;
      on)  existe $U || { echo "El registro de Pulso 36 no está instalado"; exit 3; }
           priv systemctl enable --now $U > /dev/null 2>&1 && echo "Registro de batería encendido" ;;
      off) existe $U || { echo "El registro de Pulso 36 no está instalado"; exit 3; }
           priv systemctl disable --now $U > /dev/null 2>&1 && echo "Registro de batería apagado" ;;
      *) exit 2 ;;
    esac ;;

  internet)
    # una línea por paso: PASO|n|ok o no|detalle   (ping puede necesitar administrador)
    ms() { sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p' | head -1 | awk '{printf "%d ms", $1 + 0.5}'; }
    wifi=$(wifi_if)
    gw=$(ip route | awk '/^default/{print $3; exit}')
    pingar() { ping -c1 -W3 "$1" 2>&1 || { sudo -n true 2> /dev/null && sudo -n ping -c1 -W3 "$1" 2>&1; }; }
    if [ -n "$gw" ] && r=$(pingar "$gw"); then echo "PASO|1|ok|responde · $(echo "$r" | ms)"
    else echo "PASO|1|no|no responde"; fi
    if r=$(pingar 1.1.1.1); then echo "PASO|2|ok|sí · $(echo "$r" | ms)"
    elif t=$(curl -sS -o /dev/null -m 6 -w "%{time_total}" http://1.1.1.1 2> /dev/null); then
      echo "PASO|2|ok|sí · $(echo "$t" | awk '{printf "%d ms", $1 * 1000}') (la red no deja hacer ping)"
    else echo "PASO|2|no|no llega"; fi
    if getent hosts google.com > /dev/null 2>&1; then echo "PASO|3|ok|sí"
    else   # repara: reinicia el DNS de la consola y vuelve a aplicar el Wifi
      echo "PASO|3|arreglando|falla: reiniciando el DNS"
      sudo -n systemctl restart systemd-resolved 2> /dev/null; sleep 3
      [ -n "$wifi" ] && sudo -n nmcli device reapply "$wifi" > /dev/null 2>&1; sleep 4
      if getent hosts google.com > /dev/null 2>&1; then echo "PASO|3|ok|arreglado (se reinició el DNS)"; else echo "PASO|3|no|sigue fallando"; fi
    fi
    t=$(curl -sS -o /dev/null -m 15 -w "%{http_code} %{time_total}" https://www.google.com 2> /dev/null)
    case "$t" in 2*|3*) echo "PASO|4|ok|sí · $(echo "$t" | awk '{printf "%d ms", $2 * 1000}')";; *) echo "PASO|4|no|no abre";; esac ;;

  servicios)
    # Solo SSH: Samba y FileBrowser abren la SD sin clave. «apagar» cierra también los que haya encendido el sistema.
    case "$2" in
      ssh)
        existe ssh.service || { echo "Este sistema no tiene SSH"; exit 3; }
        ip route | grep -q '^default' || { echo "No hay red: conéctate primero al Wifi"; exit 1; }
        priv systemctl start ssh.service || exit 1
        echo "SSH encendido (se apaga al reiniciar)" ;;
      apagar)
        priv systemctl stop ssh.service smbd nmbd 2> /dev/null
        priv pkill -x filebrowser 2> /dev/null
        echo "Servicios remotos apagados" ;;
      *) echo "Servicio desconocido"; exit 2 ;;
    esac ;;

  banda)    # solo la red Wifi conectada: 24 = solo 2,4 GHz; auto = la que elija la consola (deshace lo anterior)
    wifi=$(wifi_if)
    red=$(nmcli -t -f NAME,DEVICE connection show --active 2> /dev/null | awk -F: -v w="$wifi" '$2==w{print $1; exit}')
    [ -n "$red" ] || { echo "No hay una red Wifi conectada"; exit 1; }
    case "$2" in 24) b=bg; txt="«$red» fijada a 2,4 GHz" ;; auto) b=""; txt="«$red» en banda automática" ;; *) exit 2 ;; esac
    priv nmcli connection modify "$red" 802-11-wireless.band "$b" || exit 1
    priv nmcli connection up "$red" > /dev/null 2>&1
    echo "$txt" ;;

  cerrar)   # cierra un programa trabado: primero amable (TERM), a los 3 s a la fuerza (KILL)
    # Se comprueba aquí, no solo en la app: el pid tiene que seguir siendo el mismo programa (nombre), ser de un
    # usuario normal (uid ≥ 1000) y no estar en la lista de protegidos. Sin sudo: solo programas del propio usuario.
    pid="$2"; nombre="$3"
    case "$pid" in ''|*[!0-9]*) echo "Programa no válido"; exit 2 ;; esac
    [ "$pid" -gt 1 ] || exit 2
    n=$(cat /proc/$pid/comm 2> /dev/null) || { echo "Ya no estaba abierto"; exit 0; }
    [ -z "$nombre" ] || [ "$n" = "$nombre" ] || { echo "Ese programa ya se había cerrado"; exit 0; }
    uid=$(awk '/^Uid:/{print $2}' /proc/$pid/status 2> /dev/null)
    [ "${uid:-0}" -ge 1000 ] || { echo "No se cierran programas del sistema"; exit 1; }
    case "$n" in emulationstatio*|sshd|systemd*|dbus*) echo "No se cierra $n: es parte del sistema"; exit 1 ;; esac
    [ "$pid" = "$PPID" ] && { echo "No se cierra Pulso 36 desde sí mismo"; exit 1; }
    kill -TERM "$pid" 2> /dev/null
    for _ in 1 2 3 4 5 6; do sleep 0.5; [ -d /proc/$pid ] || { echo "Cerrado: $n"; exit 0; }; done
    kill -KILL "$pid" 2> /dev/null; sleep 0.5
    [ -d /proc/$pid ] && { echo "No se pudo cerrar $n"; exit 1; }
    echo "Cerrado a la fuerza: $n" ;;

  energia)  # reiniciar el menú o la consola, apagar, y apagar sola al terminar de cargar
    U=pulso36-apagar-al-cargar
    case "$2" in
      menu)      priv systemd-run --on-active=2 --unit=pulso36-reiniciar-menu systemctl restart emulationstation > /dev/null 2>&1 \
                   && echo "Reiniciando el menú…" ;;
      reiniciar) sync; priv systemd-run --on-active=2 systemctl reboot > /dev/null 2>&1 && echo "Reiniciando la consola…" ;;
      apagar)    sync; priv systemd-run --on-active=2 systemctl poweroff > /dev/null 2>&1 && echo "Apagando la consola…" ;;
      vigilar)
        cargador || { echo "Conecta el cargador primero"; exit 1; }
        systemctl is-active --quiet $U && { echo "Ya estaba vigilando"; exit 0; }
        priv systemd-run --unit=$U --description="Pulso 36: apagar al terminar de cargar" \
          --setenv=PULSO_CONF="$CONF" /bin/bash "$CASA/apagar-al-cargar.sh" > /dev/null 2>&1 \
          && echo "Se apagará sola al terminar de cargar" ;;
      cancelar)
        priv systemctl stop $U 2> /dev/null
        # el log lo crea root (systemd-run): se escribe igual, para no fallar donde la SD guarda dueños (ext4)
        priv mkdir -p "$CONF"; echo "$(date '+%F %T') cancelado desde Pulso 36" | priv tee -a "$CONF/apagar-al-cargar.log" > /dev/null
        echo "Ya no se apagará sola" ;;
      *) exit 2 ;;
    esac ;;

  ocupa)    # cuánto ocupa cada carpeta de la SD (KB), una línea apenas termina cada una; la app ordena
    echo "TOTAL=$(ls -d "$ROMS"/*/ 2> /dev/null | wc -l)"
    for c in "$ROMS"/*/; do nice -n 10 du -sk "$c" 2> /dev/null; done ;;

  *) echo "Uso: acciones.sh modo|zram|registro|internet|servicios|banda|cerrar|energia|ocupa"; exit 2 ;;
esac
