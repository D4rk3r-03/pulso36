#!/bin/bash
# Sensores falsos «vivos» para grabar un video: copia herramientas/prueba/raiz a $1 y cada 0,4 s cambia la carga de
# CPU, las frecuencias, la corriente, la temperatura y el tráfico de red. Sale cuando se borra $1/.vivo.
R=${1:?falta la carpeta}; P=$(cd "$(dirname "$0")" && pwd)
rm -rf "${R:?}"; mkdir -p "$R"; cp -r "$P/raiz/." "$R/"; touch "$R/.vivo"
B=$R/sys/class/power_supply/battery; C=$R/sys/devices/system/cpu
echo Discharging > $B/status; echo 0 > $R/sys/class/power_supply/ac/online; echo 0 > $R/sys/class/power_supply/usb/online
echo 72 > $B/capacity; echo 3790000 > $B/voltage_now; echo ondemand > $C/cpu0/cpufreq/scaling_governor
FREQS=(1008000 1200000 1248000 1296000 1512000)
declare -a U I; for i in 0 1 2 3; do U[$i]=100000; I[$i]=400000; done
RX=812345678; TX=45678901; t=0
escribir() { printf '%s\n' "$2" > "$1.tmp" && mv "$1.tmp" "$1"; }
while [ -e "$R/.vivo" ]; do
  t=$((t + 1)); base=$(( 25 + (t % 40 < 20 ? t % 20 : 20 - t % 20) * 2 ))   # sube y baja entre 25 y 65 %
  stat="cpu  0 0 0 0 0 0 0 0 0 0"$'\n'
  for i in 0 1 2 3; do
    uso=$(( base + RANDOM % 20 - 10 )); [ $uso -lt 3 ] && uso=3
    U[$i]=$(( U[$i] + uso )); I[$i]=$(( I[$i] + 100 - uso ))
    stat+="cpu$i ${U[$i]} 0 0 ${I[$i]} 0 0 0 0 0 0"$'\n'
    f=${FREQS[$(( (base + RANDOM % 25) * 5 / 100 > 4 ? 4 : (base + RANDOM % 25) * 5 / 100 ))]}
    escribir $C/cpu$i/cpufreq/scaling_cur_freq $f
  done
  escribir $R/proc/stat "$stat"
  escribir $B/current_now "-$(( 420000 + base * 2500 + RANDOM % 30000 ))"
  escribir $R/sys/class/thermal/thermal_zone0/temp $(( 46000 + base * 120 + RANDOM % 800 ))
  escribir $R/sys/class/thermal/thermal_zone1/temp $(( 44000 + base * 110 + RANDOM % 800 ))
  escribir $R/sys/class/devfreq/ff400000.gpu/cur_freq $([ $base -gt 50 ] && echo 520000000 || echo 400000000)
  RX=$(( RX + 150000 + RANDOM * 8 )); TX=$(( TX + 20000 + RANDOM ))
  escribir $R/proc/net/dev "Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:    1234      10    0    0    0     0          0         0     1234      10    0    0    0     0       0          0
 wlan0: $RX  900000    0    0    0     0          0         0 $TX  300000    0    0    0     0       0          0"
  sleep 0.4
done
