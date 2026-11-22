#!/bin/bash
# Revisión rápida (la misma que corre GitHub Actions): sintaxis de Lua y de los scripts, y traducciones completas.
# Uso, desde cualquier carpeta: herramientas/revisar.sh      (necesita luajit)
set -u
cd "$(dirname "$0")/.." || exit 1
fallos=0
echo "== Lua"
while IFS= read -r -d '' f; do luajit -bl "$f" > /dev/null || { echo "  error: $f"; fallos=$((fallos + 1)); }; done < <(git ls-files -z '*.lua')
echo "== scripts"
while IFS= read -r -d '' f; do
  head -1 "$f" | grep -qE '^#!.*\b(ba)?sh\b' || continue
  bash -n "$f" || { echo "  error: $f"; fallos=$((fallos + 1)); }
done < <(git ls-files -z)
echo "== traducciones"
luajit herramientas/revisar-traducciones.lua || fallos=$((fallos + 1))
[ "$fallos" -eq 0 ] && echo "Todo bien." || { echo "$fallos problema(s)."; exit 1; }
