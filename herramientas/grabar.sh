#!/bin/bash
# Graba un video de Pulso 36 en un PC Linux (LÖVE 11.5 por Flatpak + ffmpeg) con sensores falsos que se mueven.
# Uso: herramientas/grabar.sh "<guion>" salida.mp4 [segundos a recortar al inicio] [tema inicial: fosforo|nube]
# (mismo guion que capturas.sh; PULSO_IDIOMA=en para inglés)
D=$(cd "$(dirname "$0")/.." && pwd); P=$D/herramientas/prueba; V=$D/capturas/vivo
G="$HOME/.var/app/org.love2d.love2d/data/love/pulso36"; mkdir -p "$G"; rm -f "${G:?}"/*.png "$G/tema.txt"; printf %s "${4:-fosforo}" > "$G/tema.txt"
bash "$P/vivo.sh" "$V" & VIVO=$!; sleep 1.5
timeout 300 flatpak run --env=PULSO_GRABAR=1 --env=PULSO_RAIZ="$V" --env=PULSO_AYUDANTE="bash $P/ayudante-falso.sh" \
  --env=PULSO_ACCIONES="bash $P/acciones-falsas.sh" --env=PULSO_REGISTRO="$P/bateria/" --env=PULSO_MAH=3000 \
  --env=PULSO_SOLO_TECLADO=1 --env=PULSO_PROCESOS="sh $P/procesos-falsos.sh" --env=PULSO_IDIOMA="${PULSO_IDIOMA:-es}" \
  --env=PULSO_GUION="$1" org.love2d.love2d "$D/pulso36/juego" 2>&1 | grep -iv "alsoft\|^$" | head -20
rm -f "$V/.vivo"; wait $VIVO
n=$(ls "$G"/g*.png 2>/dev/null | wc -l); echo "$n cuadros"
[ "$n" -gt 0 ] && ffmpeg -loglevel error -y -framerate 30 -start_number $(( ${3:-0} * 30 + 1 )) -i "$G/g%05d.png" -vf "scale=1280:960:flags=neighbor,format=yuv420p" \
  -c:v libx264 -crf 18 -preset slow -movflags +faststart "$2" && ls -l "$2"
rm -f "$G"/g*.png
