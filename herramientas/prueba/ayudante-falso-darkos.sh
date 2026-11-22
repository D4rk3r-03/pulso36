#!/bin/bash
# Como ayudante-falso.sh, pero imitando un dArkOS recién instalado: SSH encendido, ZRam del sistema
# (con «ZRam Manager») apagada y la red fijada a 2,4 GHz.
bash "$(dirname "$0")/ayudante-falso.sh" "$@" | sed -e 's/^SERVICIOS=000$/SERVICIOS=100/' -e 's/^BANDA=$/BANDA=bg/' \
  -e 's/^ZRAM=pulso36$/ZRAM=sistema\nZRAM_GESTOR=ZRam Manager/' -e '/^ZRAM_ARRANQUE=/d' -e '/^ZRAM_TAM=/d'
