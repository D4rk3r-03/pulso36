#!/bin/bash
# Saca una captura de lo que muestra la pantalla de la consola (framebuffer, 640×480) y la trae al PC.
# Uso: herramientas/captura-consola.sh <nombre> <destino-ssh>     p. ej. captura-consola.sh bateria ark@192.168.1.50
# Necesita ffmpeg en la consola y sudo sin contraseña (ArkOS/dArkOS). Queda en capturas-consola/<nombre>.png
set -euo pipefail
NOMBRE="${1:?falta el nombre}"; DESTINO="${2:?falta el destino ssh, p. ej. ark@192.168.1.50}"
D=$(cd "$(dirname "$0")/.." && pwd); mkdir -p "$D/capturas-consola"
ssh -n "$DESTINO" 'sudo -n timeout 10 ffmpeg -nostdin -loglevel error -y -f fbdev -i /dev/fb0 -frames:v 1 /dev/shm/pulso-captura.png'
ssh -n "$DESTINO" 'cat /dev/shm/pulso-captura.png && sudo -n rm -f /dev/shm/pulso-captura.png' > "$D/capturas-consola/$NOMBRE.png"
echo "$D/capturas-consola/$NOMBRE.png"
