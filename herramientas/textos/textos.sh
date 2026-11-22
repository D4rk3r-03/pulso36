#!/bin/bash
# textos.sh <salida/>: corre los escenarios y guarda los textos dibujados de cada uno (números como #)
# Compara dos versiones: correr con cada una y «diff» de las carpetas (los números ya van como #; el tráfico de red
# real de la PC cambia entre corridas: normalizar «# B/s» y «#,# KB/s»).
J=$(dirname "$0"); O=${1:?carpeta de salida}; mkdir -p "$O"
D=$(cd "$(dirname "$0")/../.." && pwd); P=$D/herramientas/prueba
G="$HOME/.var/app/org.love2d.love2d/data/love/pulso36"; mkdir -p "$G"
while IFS='|' read -r nom ay raiz reg guion; do
  rm -f "$G"/*.png "$G"/tema.txt "$G"/modo.txt "$G"/ocupa.txt "$G"/textos-vistos.txt
  timeout 120 flatpak run --env=PULSO_RAIZ="$P/$raiz" --env=PULSO_AYUDANTE="bash $P/$ay" \
    --env=PULSO_ACCIONES="bash $P/acciones-falsas.sh" --env=PULSO_REGISTRO="$P/$reg" --env=PULSO_MAH=3000 \
    --env=PULSO_SOLO_TECLADO=1 --env=PULSO_IDIOMA="${PULSO_IDIOMA:-es}" --env=PULSO_TEXTOS=1 --env=PULSO_GUION="$guion" org.love2d.love2d "$D/pulso36/juego" > "$O/$nom.log" 2>&1
  if [ -f "$G/textos-vistos.txt" ]; then sed -E 's/[0-9]+/#/g' "$G/textos-vistos.txt" | sort -u > "$O/$nom.txt"; echo "$nom: $(wc -l < "$O/$nom.txt") textos"
  else echo "$nom: SIN TEXTOS"; tail -3 "$O/$nom.log"; fi
done < "$J/escenarios.txt"
