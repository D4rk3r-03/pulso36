#!/bin/bash
# Prueba Pulso 36 en un PC Linux con LÖVE 11.5 (Flatpak org.love2d.love2d) y datos inventados de herramientas/prueba.
# Uso: herramientas/capturas.sh "<guion>"   p. ej. "espera 4;foto tablero.png;a;espera 2;foto bateria.png;salir"
# Pasos del guion: espera <s> · foto <archivo.png> · un botón (a, b, x, y, l, r, arriba, abajo, izq, der, start) · salir
# Las fotos quedan en capturas/. Variables PULSO_* de desarrollo: RAIZ (sensores falsos), AYUDANTE, ACCIONES,
# REGISTRO, MAH, SOLO_TECLADO, GUION, IDIOMA (es por defecto; PULSO_IDIOMA=en herramientas/capturas.sh … para inglés).
D=$(cd "$(dirname "$0")/.." && pwd); P=$D/herramientas/prueba
G="$HOME/.var/app/org.love2d.love2d/data/love/pulso36"; mkdir -p "$G"; rm -f "${G:?}"/*.png "$G/tema.txt"
timeout 90 flatpak run --env=PULSO_RAIZ="$P/raiz" --env=PULSO_AYUDANTE="bash $P/ayudante-falso.sh" \
  --env=PULSO_ACCIONES="bash $P/acciones-falsas.sh" --env=PULSO_REGISTRO="$P/bateria/" --env=PULSO_MAH=3000 \
  --env=PULSO_SOLO_TECLADO=1 --env=PULSO_PROCESOS="sh $P/procesos-falsos.sh" --env=PULSO_IDIOMA="${PULSO_IDIOMA:-es}" --env=PULSO_AVISO="${PULSO_AVISO:-}" --env=PULSO_GUION="$1" org.love2d.love2d "$D/pulso36/juego" 2>&1 | grep -iv "alsoft\|^$" | head -20
mkdir -p "$D/capturas"; cp "$G"/*.png "$D/capturas/" 2>/dev/null; ls "$G"
