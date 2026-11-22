#!/bin/bash
# Pulso 36: system monitor for ArkOS / dArkOS handhelds (RK3326). Needs PortMaster with the LÖVE 11.5 runtime.
# Copy this file and the "pulso36" folder into your ports folder.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/pulso36"
CONF="$GAMEDIR/conf"
mkdir -p "$CONF"
cd "$GAMEDIR" || exit 1
exec > "$CONF/log.txt" 2>&1

LOVE_TXT="$controlfolder/runtimes/love_11.5/love.txt"
if [ ! -f "$LOVE_TXT" ]; then
  echo "Pulso 36: falta el runtime LÖVE 11.5 de PortMaster / LÖVE 11.5 runtime missing (install it from PortMaster)"
  pm_message "Pulso 36: install the LÖVE 11.5 runtime from PortMaster" 2> /dev/null
  sleep 5
  pm_finish
  exit 1
fi

# Where the app lives, where the games are, and where it keeps its settings and log
export PULSO_CASA="$GAMEDIR/"
export PULSO_ROMS="/$directory"
export PULSO_CONF="$CONF/"
export XDG_DATA_HOME="$CONF"          # LÖVE keeps the theme here (conf/love/pulso36)
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export PULSO_SOLO_TECLADO=1

source "$LOVE_TXT"
$GPTOKEYB "$LOVE_GPTK" -c "$GAMEDIR/juego/controles.gptk" &
pm_platform_helper "$LOVE_BINARY"
$LOVE_RUN "$GAMEDIR/juego"
pm_finish
