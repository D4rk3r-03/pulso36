#!/bin/sh
# Procesos inventados de una consola con Pulso 36 abierto, en el formato de /proc/<pid>/stat (para las capturas).
# Columnas: pid, nombre, % de CPU (de los 4 núcleos), MB de RAM. Los tiempos crecen con el reloj para que haya uso.
cs=$(( $(date +%s%N) / 10000000 ))
while read -r pid comm cpu mb; do
  awk -v p="$pid" -v c="$comm" -v u="$cpu" -v m="$mb" -v t="$cs" 'BEGIN {
    ticks = int(t * u * 4 / 100) % 100000000; rss = int(m * 256)
    printf "%s (%s) S 1 %s %s 0 -1 4194560 0 0 0 0 %d 0 0 0 20 0 1 0 100 0 %d\n", p, c, p, p, ticks, rss }'
done <<LISTA
1201 love 3.1 38
612 emulationstatio 0.6 96
1230 gptokeyb 0.3 3
455 NetworkManager 0.2 9
470 wpa_supplicant 0.1 4
530 smbd 0 11
520 sshd 0 5
1 systemd 0 7
300 systemd-journal 0 6
480 systemd-timesyn 0 3
LISTA
