#!/bin/bash
# Como capturas.sh, con otro ayudante, raíz y registro: probar-variante.sh <ayudante> <raiz> <registro/> "<guion>"
D=$(cd "$(dirname "$0")/.." && pwd); P=$D/herramientas/prueba
G="$HOME/.var/app/org.love2d.love2d/data/love/pulso36"; mkdir -p "$G"; rm -f "${G:?}"/*.png "$G/tema.txt"
timeout 120 flatpak run --env=PULSO_RAIZ="$P/$2" --env=PULSO_AYUDANTE="bash $P/$1" \
  --env=PULSO_ACCIONES="bash $P/acciones-falsas.sh" --env=PULSO_REGISTRO="$P/$3" --env=PULSO_MAH=3000 \
  --env=PULSO_SOLO_TECLADO=1 --env=PULSO_IDIOMA="${PULSO_IDIOMA:-es}" --env=PULSO_GUION="$4" org.love2d.love2d "$D/pulso36/juego" 2>&1 | grep -iv "alsoft\|^$" | head -20
mkdir -p "$D/capturas"; cp "$G"/*.png "$D/capturas/" 2>/dev/null; ls "$G"
