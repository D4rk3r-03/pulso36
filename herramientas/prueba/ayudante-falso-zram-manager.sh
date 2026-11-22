#!/bin/bash
# Como dArkOS con la ZRam configurada por su «ZRam Manager» (447 MB, lzo, arranca sola).
bash "$(dirname "$0")/ayudante-falso-darkos.sh" "$@" | sed -e 's/^ZRAM_GESTOR=ZRam Manager$/ZRAM_GESTOR=ZRam Manager\nZRAM_CONF_MB=447\nZRAM_CONF_ALGO=lzo\nZRAM_SIS_ARRANQUE=1/'
