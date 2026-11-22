#!/bin/bash
# Pulso 36: lo que no se lee directo de /sys y /proc. Una línea CLAVE=valor por dato.
#   ayudante.sh rapido   cada 5 s: discos, Wifi, servicios encendidos (pocos programas: cada uno cuesta en la consola)
#   ayudante.sh          completo, al abrir, cada minuto y después de cada acción: además permisos, banda del Wifi y
#                        qué servicios están instalados (no cambian solos)
R="${PULSO_ROMS:-/roms}"; R="${R%/}"; R="${R:-/}"   # sin barra final, como la busca la app
for d in / "$R" /boot; do   # con la ruta pedida (no el punto de montaje), como la busca la app
  df -Pk "$d" 2> /dev/null | awk -v d="$d" 'NR>1{print "DISCO="d"|"$3"|"$2}'
done
# Wifi: la primera interfaz inalámbrica (wlan0 casi siempre). Los datos del enlace con iw (ArkOS) o, si no está
# (dArkOS), con nmcli sin volver a buscar redes
W=""
for n in /sys/class/net/*/wireless; do [ -e "$n" ] && { W=$(basename "$(dirname "$n")"); break; }; done
if [ -n "$W" ]; then
  echo "WIFI=$W"
  if command -v iw > /dev/null; then
    iw dev "$W" link 2> /dev/null | awk '
      /SSID:/      {sub(/^[ \t]*SSID: /, ""); print "SSID="$0}
      /freq:/      {print "FREQ="$2}
      /tx bitrate:/{print "ENLACE="$3}'
  elif [ "$1" = rapido ]; then   # nmcli despierta a dbus y NetworkManager: solo en la vuelta completa (cada minuto)
    echo "WIFI_IGUAL=1"          # la app conserva red, frecuencia y velocidad mientras siga la misma IP
  else   # IN-USE:FREQ:RATE:SSID; el SSID va al final porque puede traer «:» (nmcli los escapa como «\:»)
    nmcli -t -f IN-USE,FREQ,RATE,SSID device wifi list ifname "$W" --rescan no 2> /dev/null | awk '
      /^\*/ { s = $0; sub(/^\*:/, "", s)
              split(s, c, ":"); f = c[1]; r = c[2]; sub(/ .*/, "", f); sub(/ .*/, "", r)
              sub(/^[^:]*:[^:]*:/, "", s); gsub(/\\:/, ":", s)
              print "SSID=" s; print "FREQ=" f; print "ENLACE=" r; exit }'
  fi
  ip -4 -o addr show "$W" 2> /dev/null | awk '{split($4, a, "/"); print "IP="a[1]; exit}'
fi
ip route 2> /dev/null | awk '/^default/{print "ROUTER="$3; exit}'
# encendidos: un solo systemctl para todos (una línea por unidad, en orden)
{ read -r ssh; read -r smb; read -r reg; read -r regv; read -r vig; } < <(systemctl is-active ssh smbd pulso36-registro bateria-registro pulso36-apagar-al-cargar 2> /dev/null)
pgrep -x filebrowser > /dev/null && f=1 || f=0
echo "SERVICIOS=$([ "$ssh" = active ] && echo 1 || echo 0)$([ "$smb" = active ] && echo 1 || echo 0)$f"
{ [ "$reg" = active ] || [ "$regv" = active ]; } && echo "REGISTRO=1" || echo "REGISTRO=0"
[ "$vig" = active ] && echo "VIGILA=1" || echo "VIGILA=0"
[ "$1" = rapido ] && exit 0

echo "COMPLETO=1"
if [ -n "$W" ]; then
  red=$(nmcli -t -f NAME,DEVICE connection show --active 2> /dev/null | awk -F: -v w="$W" '$2==w{print $1; exit}')
  [ -n "$red" ] && echo "BANDA=$(nmcli -g 802-11-wireless.band connection show "$red" 2> /dev/null)"
fi
# permisos de administrador: root, o sudo sin contraseña
{ [ "$(id -u)" = 0 ] || sudo -n true 2> /dev/null; } && echo "SUDO=1" || echo "SUDO=0"
U=/etc/systemd/system
existe() { [ -f "$U/$1.service" ] || [ -f "/lib/systemd/system/$1.service" ] || [ -f "/usr/lib/systemd/system/$1.service" ]; }
# ZRam: pulso36 = la nuestra · sistema = otra (del sistema operativo o puesta a mano) · no = se puede instalar · nada
# Herramienta del sistema para cambiarla (dArkOS trae «ZRam Manager.sh» en /opt/system) y lo que dejó configurado:
# /etc/zram.conf (ZRAM_SIZE_MB, ZRAM_ALGORITHM) y zram-swap.service. Se informa en los dos casos: si conviven con
# pulso36-zram, chocan (las dos usan /dev/zram0).
g=$(find /opt/system/Tools /opt/system -maxdepth 1 -iname '*zram*.sh' 2> /dev/null | head -1)
[ -n "$g" ] && { g=${g##*/}; echo "ZRAM_GESTOR=${g%.sh}"; }
zs=0; [ -f "$U/zram-swap.service" ] && zs=1
if [ -r /etc/zram.conf ]; then   # se lee, no se ejecuta
  echo "ZRAM_CONF_MB=$(sed -n 's/^ZRAM_SIZE_MB=\([0-9]*\)$/\1/p' /etc/zram.conf | tail -1)"
  echo "ZRAM_CONF_ALGO=$(sed -n 's/^ZRAM_ALGORITHM=\([A-Za-z0-9-]*\)$/\1/p' /etc/zram.conf | tail -1)"
fi
[ "$zs" = 1 ] && { [ -e "$U/multi-user.target.wants/zram-swap.service" ] || [ -e "$U/swap.target.wants/zram-swap.service" ]; } \
  && echo "ZRAM_SIS_ARRANQUE=1" || echo "ZRAM_SIS_ARRANQUE=0"
if existe pulso36-zram; then
  echo "ZRAM=pulso36"
  [ -e /etc/systemd/system/multi-user.target.wants/pulso36-zram.service ] && echo "ZRAM_ARRANQUE=1" || echo "ZRAM_ARRANQUE=0"
  t=$(sed -n 's/^TAMANO_MB=\([0-9]*\)$/\1/p' /etc/default/pulso36-zram 2> /dev/null | tail -1); echo "ZRAM_TAM=${t:-512}"
  [ "$zs" = 1 ] && echo "ZRAM_CHOQUE=1"
elif grep -q '^/dev/zram' /proc/swaps 2> /dev/null \
  || ls /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system /usr/local/bin /opt/system 2> /dev/null | grep -qi zram \
  || [ -e /etc/systemd/zram-generator.conf ]; then
  echo "ZRAM=sistema"
elif [ -d /sys/block/zram0 ] || [ -n "$(find /lib/modules/"$(uname -r)" -name 'zram.ko*' 2> /dev/null | head -1)" ]; then echo "ZRAM=no"
else echo "ZRAM=nada"; fi
# registro de batería: pulso36 (con su carpeta) · otro (un servicio anterior) · no
if existe pulso36-registro; then
  echo "REGISTRO_SERVICIO=pulso36"
  d=$(sed -n 's/^DIR=//p' /etc/default/pulso36-registro 2> /dev/null | tail -1); [ -n "$d" ] && echo "REGISTRO_DIR=$d"
elif existe bateria-registro; then echo "REGISTRO_SERVICIO=otro"
else echo "REGISTRO_SERVICIO=no"; fi
existe ssh && echo "SSH_SERVICIO=1" || echo "SSH_SERVICIO=0"
