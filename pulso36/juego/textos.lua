-- Textos de la interfaz de Pulso 36.
-- En el código cada texto va como T"…" o T("… %s …", valor): la clave es el texto en español. Cada idioma es una
-- tabla español → traducción; si a un texto le falta traducción, sale en español (nunca se rompe).
-- Las frases con datos usan los huecos de string.format (%s, %d…); un % literal se escribe %% solo en esas.
-- Los mensajes de acciones.sh llegan en español y se traducen igual; los que traen datos (el nombre de la red,
-- los ms de la prueba de internet…) van en «patrones».
local M = {idioma = "es"}

-- Idioma: PULSO_IDIOMA (pruebas) → idioma= en conf/ajustes.txt → el del menú (EmulationStation guarda «Language» en
-- ~/.emulationstation/es_settings.cfg solo si se cambió; por defecto es inglés) → el del sistema (LANG…) → inglés.
local function cual(v)
    v = tostring(v or ""):lower()
    if v:match("^es") then return "es" elseif v:match("^en") then return "en" end
end
function M.elegir(ajuste)
    local i = cual(os.getenv("PULSO_IDIOMA")) or cual(ajuste)
    if not i then
        local f = io.open((os.getenv("HOME") or "/home/ark") .. "/.emulationstation/es_settings.cfg", "r")
        if f then
            local t = f:read("*a") or ""; f:close()
            i = cual(t:match('name="Language"%s+value="([^"]*)"'))
        end
    end
    for _, v in ipairs({"LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"}) do i = i or cual(os.getenv(v)) end
    M.idioma = i or "en"
    M.cache = {}
    return M.idioma
end

M.en = {
    -- avisos y mensajes generales
    ["Esta consola no deja cambiar el sistema: Pulso 36 solo mostrará datos."] = "This console does not allow system changes: Pulso 36 will only show data.",
    ["La orden tardó demasiado; revisa si se hizo."] = "The command took too long; check whether it worked.",
    ["Listo."] = "Done.", ["No se pudo."] = "Could not do it.", ["Cerrado."] = "Closed.", ["No se pudo cerrar."] = "Could not close it.",
    ["No se pudo cambiar el modo."] = "Could not change the governor.",
    ["Sí"] = "Yes", ["No"] = "No", ["sí"] = "yes", ["no"] = "no",
    ["Tema %s"] = "Theme: %s", ["fósforo"] = "phosphor", ["nube"] = "cloud",
    -- aviso de batería baja
    ["Aviso de batería"] = "Battery warning",
    ["BATERÍA BAJA"] = "LOW BATTERY", ["BATERÍA CRÍTICA"] = "CRITICAL BATTERY", ["BATERÍA AGOTADA"] = "BATTERY EMPTY",
    ["CARGADOR CONECTADO"] = "CHARGER CONNECTED", ["La consola ya no se apagará."] = "The console will not shut down.",
    ["Quedan unos %d min. Conecta el cargador pronto."] = "About %d min left. Plug in the charger soon.",
    ["Quedan unos %d min. Guarda tu partida y conecta el cargador."] = "About %d min left. Save your game and plug in the charger.",
    ["Guarda tu partida y conecta el cargador ya."] = "Save your game and plug in the charger now.",
    ["La consola se apaga en %d s. Conecta el cargador para cancelarlo."] = "Shutting down in %d s. Plug in the charger to cancel.",
    ["Volver"] = "Back", ["Desinstalar"] = "Uninstall", ["Instalar"] = "Install", ["Apagar"] = "Turn off", ["Encender"] = "Turn on",
    ["Cancelar"] = "Cancel", ["Elegir"] = "Select", ["Cerrar"] = "Close", ["Hacer"] = "Apply",
    ["encendida %s"] = "on for %s",
    -- procesos: nombres
    ["Menú (EmulationStation)"] = "Menu (EmulationStation)", ["Samba (nombres)"] = "Samba (names)",
    ["Red (NetworkManager)"] = "Network (NetworkManager)", ["Registro del sistema"] = "System log",
    ["Sistema (systemd)"] = "System (systemd)", ["Controles (gptokeyb)"] = "Controls (gptokeyb)",
    ["Hora (sincronización)"] = "Clock (sync)", ["SSH (conexión abierta)"] = "SSH (open session)",
    ["Audio USB (dArkOS)"] = "USB audio (dArkOS)", ["Pulso 36 (esta app)"] = "Pulso 36 (this app)", ["Sesión (systemd)"] = "Session (systemd)",
    -- tablero
    ["BATERÍA"] = "BATTERY", ["PROCESADOR"] = "CPU", ["MEMORIA"] = "MEMORY", ["ALMACENAMIENTO"] = "STORAGE", ["RED"] = "NETWORK",
    ["PROCESOS"] = "PROCESSES",
    ["Cargando"] = "Charging", ["Descargando"] = "Discharging", ["Llena"] = "Full", ["Conectada, sin cargar"] = "Plugged in, not charging",
    ["quedan %s"] = "%s left", ["llena en %s"] = "full in %s", ["menos de 5 min"] = "under 5 min", ["calculando…"] = "estimating…",
    ["se apagará al llenarse"] = "will power off when full", ["desde la carga: %s"] = "since charge: %s",
    ["con tu consumo de ahora"] = "at the current draw",
    ["MHz máx"] = "MHz max", ["%s de 4"] = "%s of 4", ["activos"] = "online", ["procesador"] = "CPU",
    ["carga %s%% · %s"] = "load %s%% · %s",
    ["en uso"] = "in use", ["%s MB libres de %s"] = "%s MB free of %s", ["%d MB en %d MB (%s:1)"] = "%d MB in %d MB (%s:1)",
    ["encendida, sin uso todavía"] = "on, not used yet", ["Sin ZRam"] = "No ZRam", ["ZRam apagada"] = "ZRam off",
    ["A para encenderla"] = "A to turn it on", ["A para instalarla"] = "A to install it", ["la maneja %s"] = "managed by %s",
    ["la maneja el sistema"] = "managed by the system",
    ["Sistema"] = "System", ["Juegos (SD)"] = "Games (SD)", ["%.1f GB libres · %d %% usado"] = "%.1f GB free · %d %% used",
    ["conectada"] = "connected", ["sin Wifi"] = "no Wi-Fi", ["2,4 GHz"] = "2.4 GHz", ["sin IP"] = "no IP",
    ["IP de la consola"] = "console IP", ["baja %s"] = "down %s", ["sube %s"] = "up %s",
    ["%s programas abiertos"] = "%s programs running",
    ["Detalle"] = "Details", ["Internet"] = "Internet", ["Tema"] = "Theme", ["Energía"] = "Power", ["Salir"] = "Quit",
    -- batería
    ["batería"] = "battery", ["AHORA"] = "NOW", ["sistema: %s%%"] = "system: %s%%",
    ["cargando"] = "charging", ["descargando"] = "discharging", ["llena"] = "full", ["conectada, sin cargar"] = "plugged in, not charging",
    ["menos de 5 min: conéctala"] = "under 5 min: plug it in",
    ["por voltaje, según tu última descarga"] = "by voltage, from your last discharge",
    ["por voltaje, según todas tus descargas"] = "by voltage, from all your discharges",
    ["según tu última carga completa"] = "from your last full charge",
    ["con %s mAh y el consumo actual"] = "with %s mAh and the current draw",
    ["la última vez se apagó en %.2f V · "] = "last shutdown at %.2f V · ", ["brillo %s"] = "brightness %s",
    ["VOLTAJE · últimos 3 min"] = "VOLTAGE · last 3 min", ["4,2 V"] = "4.2 V", ["3,4 V"] = "3.4 V",
    ["TIEMPOS"] = "TIMES", ["sin registro de batería"] = "no battery log", ["registrando cada minuto"] = "logging every minute",
    ["registro apagado"] = "log off",
    ["ESTA SESIÓN"] = "THIS SESSION", ["encendida desde %s"] = "on since %s", ["DESDE LA CARGA"] = "SINCE CHARGE",
    ["se cuenta al desconectarla"] = "counts once unplugged", ["encendida"] = "powered on", ["%s reales · desde %s"] = "%s real · since %s",
    ["hoy %s"] = "today %s", ["ayer %s"] = "yesterday %s",
    ["desde la próxima carga"] = "after the next charge", ["sin registro"] = "no log",
    ["ÚLTIMA COMPLETA"] = "LAST FULL", ["de %.2f a %.2f V"] = "from %.2f to %.2f V", ["terminó %s"] = "ended %s",
    ["cuando se apague sola"] = "after it shuts down on its own",
    ["ÚLTIMA DESCARGA COMPLETA"] = "LAST FULL DISCHARGE",
    ["TU BATERÍA · todas tus descargas"] = "YOUR BATTERY · all your discharges",
    ["%d mAh útiles · %d descargas"] = "%d mAh usable · %d discharges", ["%d mAh útiles · %d descargas · %d SD"] = "%d mAh usable · %d discharges · %d SD",
    ["lo que quedaba + lo que ha entrado"] = "what was left + what went in",
    ["UNA CARGA DURA"] = "A CHARGE LASTS", ["a %d mA, %s"] = "at %d mA, %s", ["el consumo de ahora"] = "current draw",
    ["tu última descarga"] = "your last discharge", ["de llena a %.2f V"] = "from full to %.2f V",
    ["Sin registro, el porcentaje es el del sistema y puede no ser fiable. A instala el registro de batería."] =
        "No log: the percentage comes from the system and may be wrong. A installs the battery log.",
    ["Sin registro, el porcentaje es el del sistema y puede no ser fiable."] = "No log: the percentage comes from the system and may be wrong.",
    ["Sin descargas completas en el registro: aparece cuando la consola se apague sola por batería baja."] =
        "No full discharge in the log yet: it shows up once the console shuts down on its own from low battery.",
    ["Apagar registro"] = "Turn log off", ["Encender registro"] = "Turn log on", ["Instalar registro"] = "Install log",
    ["¿Instalar el registro de batería?"] = "Install the battery log?",
    ["Anota cada minuto el voltaje, el consumo y qué juego está abierto, en %s. Funciona también con Pulso 36 cerrado. Se quita con X."] =
        "Every minute it writes down the voltage, the draw and which game is open, in %s. It also works with Pulso 36 closed. Remove it with X.",
    ["¿Desinstalar el registro?"] = "Uninstall the log?",
    ["Se borra su servicio. Lo ya anotado se queda en %s."] = "Its service is removed. What was logged stays in %s.",
    ["¿Apagar el registro de batería?"] = "Turn the battery log off?",
    ["Deja de anotar cada minuto. Lo ya registrado se queda en %s."] = "It stops logging every minute. What was logged stays in %s.",
    -- procesador
    ["Ahorro"] = "Saver", ["gasta menos batería"] = "uses less battery", ["Normal"] = "Normal",
    ["sube cuando hace falta"] = "speeds up when needed", ["Máximo"] = "Maximum", ["siempre a tope"] = "always at full speed",
    ["NÚCLEOS · últimos 90 s"] = "CORES · last 90 s", ["uso"] = "load", ["Núcleo %s"] = "Core %s", ["MHz · uso %s%%"] = "MHz · load %s%%",
    ["apagado"] = "offline", ["TEMPERATURA · PROCESADOR"] = "TEMPERATURE · CPU", ["gráficos %s · %s"] = "GPU %s · %s",
    ["memoria %s MHz"] = "memory %s MHz", ["MODO DEL PROCESADOR"] = "CPU GOVERNOR", ["Usar este modo"] = "Use this one",
    ["Ya está en modo %s."] = "Already in %s mode.", ["Modo %s. Pulso 36 lo recordará al abrirse."] = "%s mode. Pulso 36 will restore it on launch.",
    ["Procesador en modo %s (el sistema lo había puesto en máximo)."] = "CPU in %s mode (the system had set it to maximum).",
    ["Procesador en modo %s."] = "CPU in %s mode.", ["No se pudo poner el modo %s."] = "Could not set %s mode.",
    -- memoria
    ["memoria"] = "memory", ["%d MB usados · %d libres · %d total"] = "%d MB used · %d free · %d total",
    ["ZRAM · memoria comprimida"] = "ZRAM · compressed memory",
    ["Ojo: también está la de «%s». Usa solo una."] = "Careful: \"%s\" is also set up. Use only one.",
    ["No actives también «%s»: usan la misma memoria."] = "Do not turn on \"%s\" too: they share the same memory.",
    ["de memoria ganada ahora"] = "of memory gained now", ["Guardado: %d MB"] = "Stored: %d MB", ["Ocupa en la RAM: %d MB"] = "Takes in RAM: %d MB",
    ["Comprime %.1f a 1 · tamaño %d MB"] = "Compresses %.1f to 1 · size %d MB",
    ["Encendida y esperando: todavía no hizo falta · tamaño %d MB"] = "On and waiting: not needed yet · size %d MB",
    ["Apagada"] = "Off", ["No instalada"] = "Not installed",
    ["Guarda en la RAM, comprimido, lo que no cabe: los juegos pesados no se cierran de golpe por falta de memoria."] =
        "It compresses what doesn't fit in RAM, so heavy games don't suddenly close for lack of memory.",
    ["A para instalarla: Pulso 36 deja un servicio que la enciende al arrancar (se quita con X)."] =
        "A to install it: Pulso 36 adds a service that turns it on at boot (remove it with X).",
    ["Esta consola no deja instalarla (falta sudo sin contraseña)."] = "This console does not allow installing it (needs passwordless sudo).",
    ["Este sistema no trae zram."] = "This system has no zram.",
    ["Con %s MB libres ahora no hace falta. Conviene encenderla para PSP, N64 o Dreamcast, o si un juego se cierra solo."] =
        "With %s MB free it is not needed now. Turn it on for PSP, N64 or Dreamcast, or if a game closes by itself.",
    ["Quedan %s MB libres: conviene encenderla para que los juegos pesados no se cierren."] =
        "Only %s MB free: turn it on so heavy games do not close.",
    ["Al arrancar: %s"] = "At boot: %s", ["Tamaño elegido:"] = "Chosen size:",
    ["Configurada en «%s»: %s MB%s · al arrancar: %s. Se cambia desde ahí, en las opciones del menú."] =
        "Set up in \"%s\": %s MB%s · at boot: %s. Change it there, in the menu options.",
    ["La enciende «%s», en las opciones del menú. Todavía no está configurada."] =
        "\"%s\" turns it on, in the menu options. Not set up yet.",
    ["La ZRam la maneja el sistema: se cambia desde sus herramientas, no desde Pulso 36."] =
        "The system manages ZRam: change it with its own tools, not from Pulso 36.",
    ["Tamaño"] = "Size",
    ["¿Instalar ZRam?"] = "Install ZRam?",
    ["Pulso 36 instala un servicio pequeño (pulso36-zram) que la enciende con 512 MB en cada arranque. Se quita con X."] =
        "Pulso 36 installs a small service (pulso36-zram) that turns it on with 512 MB at every boot. Remove it with X.",
    ["¿Desinstalar la ZRam de Pulso 36?"] = "Uninstall Pulso 36's ZRam?",
    ["Se apaga y se borra su servicio: el sistema queda como antes de instalarla."] =
        "It is turned off and its service removed: the system is left as before.",
    ["¿Apagar ZRam?"] = "Turn ZRam off?",
    ["Lo que está guardado ahí vuelve a la RAM. Tampoco se encenderá al arrancar."] =
        "What is stored there goes back to RAM. It will not turn on at boot either.",
    ["ZRam apagada."] = "ZRam off.", ["ZRam encendida, también al arrancar."] = "ZRam on, also at boot.",
    ["¿Encender la ZRam de Pulso 36?"] = "Turn on Pulso 36's ZRam?",
    ["También está configurada la de «%s». Las dos usan la misma memoria: al arrancar, una falla o apaga a la otra. Mejor desactiva una de las dos."] =
        "\"%s\" is also set up. Both use the same memory: at boot, one fails or turns the other off. Better disable one of them.",
    -- energía
    ["Apagar al terminar de cargar"] = "Power off when charged", ["Reiniciar el menú"] = "Restart the menu",
    ["¿Reiniciar el menú?"] = "Restart the menu?",
    ["Se cierra Pulso 36 y EmulationStation vuelve a arrancar. Sirve si el menú quedó raro o lento."] =
        "Pulso 36 closes and EmulationStation starts again. Useful if the menu got glitchy or slow.",
    ["Reiniciar la consola"] = "Reboot the console", ["¿Reiniciar la consola?"] = "Reboot the console?",
    ["Se cierra todo. Guarda la partida si tienes un juego abierto."] = "Everything closes. Save your game if one is open.",
    ["Apagar la consola"] = "Power off the console", ["¿Apagar la consola?"] = "Power off the console?",
    ["energía"] = "power", ["BATERÍA AHORA"] = "BATTERY NOW",
    ["Llena de verdad: más de 4,14 V y menos de 200 mA. El sistema marca 100 % antes."] =
        "Really full: over 4.14 V and under 200 mA. The system shows 100 % earlier.",
    ["casi llena"] = "almost full", ["sin cargador"] = "no charger", ["ENERGÍA"] = "POWER",
    ["ACTIVO: vigilando la carga"] = "ON: watching the charge", ["conectada: se puede activar"] = "plugged in: ready",
    ["conecta el cargador"] = "plug in the charger",
    ["Ideal para dejarla cargando de noche. Si la desconectas, no se apaga."] = "Good for charging overnight. If you unplug it, it stays on.",
    ["Cierra Pulso 36 y vuelve a abrir EmulationStation"] = "Closes Pulso 36 and reopens EmulationStation",
    ["Apaga y vuelve a encender"] = "Turns off and on again", ["Apaga ahora"] = "Turns off now",
    -- procesos
    ["procesos"] = "processes", ["LOS QUE MÁS CONSUMEN AHORA"] = "TOP USAGE RIGHT NOW",
    ["Es parte del sistema: no se cierra desde aquí."] = "Part of the system: it cannot be closed from here.",
    ["A para cerrarlo si se quedó trabado."] = "A to close it if it got stuck.", ["%s programas"] = "%s programs",
    ["Es parte del sistema: mejor no cerrarlo."] = "Part of the system: better not close it.", ["¿Cerrar %s?"] = "Close %s?",
    ["Si es un juego, se pierde lo que no hayas guardado."] = "If it is a game, unsaved progress is lost.",
    -- almacenamiento
    ["Herramientas"] = "Tools", ["Temas"] = "Themes", ["Respaldos"] = "Backups", ["Videos"] = "Videos", ["Películas"] = "Movies",
    ["Música de fondo"] = "Background music", ["Pantallas de carga"] = "Loading screens",
    ["almacenamiento"] = "storage", ["ESPACIO LIBRE"] = "FREE SPACE", ["Arranque"] = "Boot",
    ["%s libres · %s %% usado"] = "%s free · %s %% used", ["QUÉ OCUPA LA SD"] = "WHAT FILLS THE SD",
    ["Empezando a medir las carpetas de la SD…"] = "Starting to measure the SD folders…",
    ["A para medir cuánto ocupa cada sistema. Tarda unos 20 segundos y se guarda para la próxima vez."] =
        "A to measure how much each system takes. It takes about 20 seconds and is saved for next time.",
    ["Midiendo: %s de %s carpetas"] = "Measuring: %s of %s folders", ["medido %s"] = "measured %s",
    [" (viejo · A para medir)"] = " (old · A to measure)", ["%s carpetas más: %s"] = "%s more folders: %s", ["vacías"] = "empty",
    ["Volver a medir"] = "Measure again", ["Medir"] = "Measure", ["midiendo…"] = "measuring…", ["No se pudo medir la SD."] = "Could not measure the SD.",
    -- red
    ["Encender SSH"] = "Turn on SSH", ["¿Encender SSH?"] = "Turn on SSH?",
    ["Cualquiera en esta red podrá intentar entrar con el usuario y la clave de la consola. Si nunca la cambiaste (en ArkOS es ark/ark), cámbiala antes. Se apaga al reiniciar."] =
        "Anyone on this network can try to log in with the console's user and password. If you never changed it (on ArkOS it is ark/ark), change it first. It turns off on reboot.",
    ["Apagar servicios remotos"] = "Turn off remote services", ["¿Apagar los servicios remotos?"] = "Turn off remote services?",
    ["Apaga SSH, Samba y FileBrowser. Si estás conectado desde otro equipo, se corta la conexión."] =
        "Turns off SSH, Samba and FileBrowser. If you are connected from another device, the connection drops.",
    ["Wifi solo en 2,4 GHz"] = "Wi-Fi 2.4 GHz only", ["¿Fijar esta red a 2,4 GHz?"] = "Lock this network to 2.4 GHz?",
    ["Solo la red conectada ahora. Sirve si el Wifi se corta en 5 GHz. Se deshace con «Wifi en automático»."] =
        "Only the network connected now. Useful if Wi-Fi drops on 5 GHz. Undo it with \"Wi-Fi automatic\".",
    ["Wifi en automático"] = "Wi-Fi automatic",
    ["Router"] = "Router", ["Nombres (DNS)"] = "Names (DNS)", ["Web segura"] = "Secure web",
    ["red"] = "network", [" · canal %s"] = " · channel %s", [" · fijada"] = " · locked",
    ["señal %s"] = "signal %s", ["enlace %s"] = "link %s", ["sin datos"] = "no data",
    ["excelente"] = "excellent", ["buena"] = "good", ["regular"] = "fair", ["débil"] = "weak",
    ["para entrar por SSH"] = "to log in over SSH", ["SERVICIOS REMOTOS"] = "REMOTE SERVICES", ["SSH encendido"] = "SSH on",
    ["TRÁFICO · últimos 90 s"] = "TRAFFIC · last 90 s", ["total %s / %s"] = "total %s / %s", ["máx %s"] = "max %s",
    ["PRUEBA DE INTERNET"] = "INTERNET TEST", ["Cambiar de Wifi: Opciones > Wifi"] = "Change Wi-Fi: Options > Wi-Fi",
    ["X para probar el router, internet, los nombres (DNS) y una web segura"] = "X to test the router, internet, names (DNS) and a secure website",
    ["comprobando"] = "checking", ["Probar internet"] = "Test internet",
    ["SSH ya está encendido."] = "SSH is already on.", ["Ya está así."] = "Already set.",
    -- mensajes fijos de acciones.sh
    ["Esta consola no deja cambiar el sistema (falta sudo sin contraseña)"] = "This console does not allow system changes (needs passwordless sudo)",
    ["Este sistema no tiene zram"] = "This system has no zram",
    ["ZRam instalada y encendida (también al arrancar)"] = "ZRam installed and on (also at boot)",
    ["La ZRam de Pulso 36 no está instalada"] = "Pulso 36's ZRam is not installed",
    ["ZRam de Pulso 36 desinstalada"] = "Pulso 36's ZRam uninstalled",
    ["ZRam encendida (también al arrancar)"] = "ZRam on (also at boot)", ["ZRam apagada"] = "ZRam off", ["Tamaño no válido"] = "Invalid size",
    ["Falta la carpeta del registro"] = "Log folder missing",
    ["Registro de batería instalado y encendido"] = "Battery log installed and on",
    ["El registro de Pulso 36 no está instalado"] = "Pulso 36's log is not installed",
    ["Registro desinstalado (lo ya anotado se queda)"] = "Log uninstalled (what was logged stays)",
    ["Registro de batería encendido"] = "Battery log on", ["Registro de batería apagado"] = "Battery log off",
    ["Este sistema no tiene SSH"] = "This system has no SSH", ["No hay red: conéctate primero al Wifi"] = "No network: connect to Wi-Fi first",
    ["SSH encendido (se apaga al reiniciar)"] = "SSH on (turns off on reboot)", ["Servicios remotos apagados"] = "Remote services off",
    ["Servicio desconocido"] = "Unknown service", ["No hay una red Wifi conectada"] = "No Wi-Fi network connected",
    ["Programa no válido"] = "Invalid program", ["Ya no estaba abierto"] = "It was no longer running",
    ["Ese programa ya se había cerrado"] = "That program had already closed", ["No se cierran programas del sistema"] = "System programs are not closed",
    ["No se cierra Pulso 36 desde sí mismo"] = "Pulso 36 cannot close itself",
    ["Reiniciando el menú…"] = "Restarting the menu…", ["Reiniciando la consola…"] = "Rebooting the console…",
    ["Apagando la consola…"] = "Powering off the console…", ["Conecta el cargador primero"] = "Plug in the charger first",
    ["Ya estaba vigilando"] = "Already watching", ["Se apagará sola al terminar de cargar"] = "It will power off when charged",
    ["Ya no se apagará sola"] = "It will no longer power off by itself",
    -- prueba de internet (detalle de cada paso)
    ["no responde"] = "no reply", ["no llega"] = "unreachable", ["falla: reiniciando el DNS"] = "failing: restarting DNS",
    ["arreglado (se reinició el DNS)"] = "fixed (DNS restarted)", ["sigue fallando"] = "still failing", ["no abre"] = "will not load",
}

-- mensajes con datos (de acciones.sh): patrón de Lua → traducción con %1, %2…; el primero que encaja
M.patrones = {en = {
    {"^Modo del procesador: (.+)$", "CPU governor: %1"},
    {"^Este sistema no tiene el modo (.+)$", "This system has no %1 governor"},
    {"^«(.+)» fijada a 2,4 GHz$", "\"%1\" locked to 2.4 GHz"},
    {"^«(.+)» en banda automática$", "\"%1\" on automatic band"},
    {"^Cerrado a la fuerza: (.+)$", "Force-closed: %1"},
    {"^Cerrado: (.+)$", "Closed: %1"},
    {"^No se cierra (.+): es parte del sistema$", "%1 is part of the system: not closed"},
    {"^No se pudo cerrar (.+)$", "Could not close %1"},
    {"^responde · (.+)$", "replies · %1"},
    {"^sí · (.+) %(la red no deja hacer ping%)$", "yes · %1 (ping blocked)"},
    {"^sí · (.+)$", "yes · %1"},
}}

M.cache = {}
local function traducir(s)
    local tabla = M[M.idioma]
    if M.idioma == "es" or type(tabla) ~= "table" then return s end
    if tabla[s] then return tabla[s] end
    for _, p in ipairs(M.patrones[M.idioma] or {}) do
        if s:match(p[1]) then return (s:gsub(p[1], p[2])) end
    end
    return s
end

function M.T(s, ...)
    if select("#", ...) > 0 then return string.format(traducir(s), ...) end
    local c = M.cache[s]
    if c == nil then c = traducir(s); M.cache[s] = c end
    return c
end

return M
