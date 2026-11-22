#!/bin/bash
# La ZRam de Pulso 36 instalada y también la del «ZRam Manager» de dArkOS (chocan: misma /dev/zram0).
bash "$(dirname "$0")/ayudante-falso.sh" "$@" | sed -e 's/^ZRAM=pulso36$/ZRAM=pulso36\nZRAM_GESTOR=ZRam Manager\nZRAM_CONF_MB=447\nZRAM_CONF_ALGO=lzo\nZRAM_SIS_ARRANQUE=1\nZRAM_CHOQUE=1/'
