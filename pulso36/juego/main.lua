-- Pulso 36 · el estado de la consola en vivo (pixel art, LÖVE 11.5 de PortMaster, 640×480). ArkOS y dArkOS (RK3326).
-- Lee /sys y /proc directamente cada segundo; lo demás (discos, red) lo da ayudante.sh en un hilo cada 5 s, y lo
-- que cambia el sistema (modo del procesador, ZRam, prueba de internet) lo hace acciones.sh.
local lg = love.graphics
local W, H = 640, 480

-- ── rutas y ajustes ──
-- El lanzador («Pulso 36.sh») exporta PULSO_CASA (carpeta del port), PULSO_ROMS (/roms o /roms2) y PULSO_CONF
-- (ajustes y log). Sin lanzador, la carpeta del port es la que contiene juego/. En un PC las rutas se cambian
-- por variables de entorno para probar (herramientas/capturas.sh).
local function conBarra(r) return r:sub(-1) == "/" and r or (r .. "/") end
local function citar(s) return "'" .. s:gsub("'", "'\\''") .. "'" end   -- para el shell, con espacios y comillas
local RAIZ = os.getenv("PULSO_RAIZ") or ""
local CASA = conBarra(os.getenv("PULSO_CASA") or ((love.filesystem.getSource():gsub("/juego/?$", "")) .. "/"))
local ROMS = (os.getenv("PULSO_ROMS") or "/roms"):gsub("/$", "")
local CONF = conBarra(os.getenv("PULSO_CONF") or (CASA .. "conf/"))
-- conf/ajustes.txt: una línea clave=valor por ajuste (se lee, nunca se ejecuta). Claves: mah, registro, idioma.
local AJUSTES = {}
do
    local f = io.open(CONF .. "ajustes.txt", "r")
    if f then
        for l in f:lines() do
            local k, v = l:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if k and not l:match("^%s*#") then AJUSTES[k] = v end
        end
        f:close()
    end
end
-- textos de la interfaz (textos.lua): T"…" devuelve el texto en el idioma elegido; la clave es el español
local textos = require("textos")
textos.elegir(AJUSTES.idioma)
local T = textos.T
-- ── sensores: se buscan al arrancar, no se dan por fijos (lo que no esté se muestra «—») ──
local function listar(dir)
    local t = {}
    local p = io.popen("ls -1 " .. citar(RAIZ .. dir) .. " 2>/dev/null")
    if p then for l in p:lines() do t[#t + 1] = l end; p:close() end
    return t
end
local function leerYa(r)
    local f = io.open(RAIZ .. r, "r"); if not f then return nil end
    local v = f:read("*a"); f:close(); return v and v:match("^%s*(.-)%s*$")
end
local PS = "/sys/class/power_supply/"
local BAT, CARGADORES = nil, {}     -- batería = la primera de tipo Battery; cargadores = los demás con «online»
for _, n in ipairs(listar(PS)) do
    local tipo = leerYa(PS .. n .. "/type")
    if tipo == "Battery" or (not tipo and n == "battery") then BAT = BAT or (PS .. n .. "/")
    elseif leerYa(PS .. n .. "/online") then CARGADORES[#CARGADORES + 1] = PS .. n .. "/online" end
end
local GPU     -- devfreq de la GPU
for _, n in ipairs(listar("/sys/class/devfreq/")) do if n:match("gpu") then GPU = "/sys/class/devfreq/" .. n .. "/"; break end end
local LUZ = listar("/sys/class/backlight/")[1]; LUZ = LUZ and ("/sys/class/backlight/" .. LUZ .. "/")
local AYUDANTE = os.getenv("PULSO_AYUDANTE") or ("bash " .. citar(CASA .. "ayudante.sh"))
local ACCIONES = os.getenv("PULSO_ACCIONES") or ("bash " .. citar(CASA .. "acciones.sh"))
-- carpeta del registro de batería: PULSO_REGISTRO (pruebas) → ajustes.txt → la del servicio instalado (la avisa el
-- ayudante) → conf/registro/ (donde lo instala Pulso 36)
local REGISTRO_FIJO = os.getenv("PULSO_REGISTRO") or AJUSTES.registro
local REGISTRO = conBarra(REGISTRO_FIJO or (CONF .. "registro/"))
-- capacidad de la batería en mAh: PULSO_MAH (pruebas) → ajustes.txt → la que informa el sistema → 3000
-- (igual que REGISTRO: la variable de entorno manda sobre ajustes.txt)
local CAPACIDAD = tonumber(os.getenv("PULSO_MAH") or "") or tonumber(AJUSTES.mah or "")
if not CAPACIDAD then
    local v = BAT and tonumber((leerYa(BAT .. "charge_full") or ""):match("%d+") or "")
    CAPACIDAD = v and v > 100000 and v / 1000 or 3000
end

local TEMAS = {
    fosforo = {
        fondo = {0.02, 0.05, 0.03}, trama = {0.04, 0.10, 0.06}, panel = {0.01, 0.04, 0.02}, borde = {0.10, 0.32, 0.16},
        acento = {0.40, 1.00, 0.55}, oro = {0.85, 1.00, 0.45}, alerta = {1.00, 0.55, 0.35}, crema = {0.80, 1.00, 0.84},
        tenue = {0.35, 0.68, 0.43}, pulso = {0.40, 1.00, 0.55}, marca = {0.06, 0.20, 0.10}, barrido = true,
    },
    nube = {
        fondo = {0.04, 0.07, 0.13}, trama = {0.07, 0.11, 0.20}, panel = {0.03, 0.05, 0.10}, borde = {0.17, 0.27, 0.45},
        acento = {0.42, 0.93, 0.78}, oro = {0.98, 0.82, 0.45}, alerta = {1.00, 0.50, 0.48}, crema = {0.95, 0.95, 0.90},
        tenue = {0.56, 0.66, 0.82}, pulso = {1.00, 0.42, 0.50}, marca = {0.12, 0.22, 0.38},
    },
}
local ORDEN_TEMAS = {"fosforo", "nube"}
local tema = "fosforo"
local C = TEMAS[tema]

local F, S = {}, {}
local reloj = 0
local function color(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local function px(x, y, w, h) lg.rectangle("fill", math.floor(x), math.floor(y), w or 1, h or 1) end
local function limitar(x, a, b) return math.max(a, math.min(b, x)) end
local function mezcla(a, b, t) t = limitar(t, 0, 1); return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t} end
local function suave(a, b, vel, dt) return b + (a - b) * math.exp(-vel * dt) end
local function salida(p) return 1 - (1 - p) ^ 3 end
local function coma(s) return textos.idioma == "es" and (tostring(s):gsub("%.", ",")) or tostring(s) end   -- coma decimal solo en español
-- fecha corta: «21/11 13:17» en español; en inglés «Nov 21 13:17» (día/mes confunde en Estados Unidos)
local MESES_EN = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
local function fechaCorta(t)
    if textos.idioma == "es" then return os.date("%d/%m %H:%M", t) end
    local d = os.date("*t", t)
    return string.format("%s %d %02d:%02d", MESES_EN[d.month], d.day, d.hour, d.min)
end
local function recortar(f, t, ancho)
    if f:getWidth(t) <= ancho then return t end
    -- quita una letra entera por vuelta (las letras con tilde o eñe ocupan 2 bytes en UTF-8: nunca partirlas)
    while #t > 0 and f:getWidth(t .. "…") > ancho do t = t:match("^(.-)[%z\1-\127\194-\244][\128-\191]*$") or "" end
    return t .. "…"
end
local function duracion(min)
    if not min or min ~= min or min < 0 then return "—" end
    min = math.floor(min + 0.5)
    if min < 60 then return min .. " min" end
    if min >= 24 * 60 then return math.floor(min / 1440) .. " d " .. math.floor(min % 1440 / 60) .. " h" end
    return math.floor(min / 60) .. " h " .. (min % 60) .. " min"
end

-- ── lectura de /sys y /proc ──
-- Los sensores de cada segundo NO se leen en el hilo que dibuja: leer un archivo de /sys o /proc puede quedarse
-- esperando al controlador (el Wifi tardó 17 s en responder una vez y la pantalla se congeló). Dos hilos los leen
-- y mandan una «foto»: uno para el Wifi y otro para lo demás; la app usa la última foto que llegó.
local SENSORES = {"/proc/stat", "/proc/meminfo", "/proc/swaps", "/proc/uptime",
    "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", "/sys/class/devfreq/dmc/cur_freq",
    "/sys/block/zram0/mm_stat", "/sys/block/zram0/disksize"}
for _, r in ipairs({GPU and (GPU .. "cur_freq"), BAT and (BAT .. "capacity"), BAT and (BAT .. "voltage_now"),
    BAT and (BAT .. "current_now"), BAT and (BAT .. "status"), LUZ and (LUZ .. "brightness"),
    LUZ and (LUZ .. "max_brightness")}) do SENSORES[#SENSORES + 1] = r end
for _, r in ipairs(CARGADORES) do SENSORES[#SENSORES + 1] = r end
for i = 0, 3 do
    SENSORES[#SENSORES + 1] = "/sys/devices/system/cpu/cpu" .. i .. "/online"
    SENSORES[#SENSORES + 1] = "/sys/devices/system/cpu/cpu" .. i .. "/cpufreq/scaling_cur_freq"
    SENSORES[#SENSORES + 1] = "/sys/class/thermal/thermal_zone" .. i .. "/type"
    SENSORES[#SENSORES + 1] = "/sys/class/thermal/thermal_zone" .. i .. "/temp"
end
local SENSORES_WIFI = {"/proc/net/wireless", "/proc/net/dev"}
local esSensor = {}
for _, r in ipairs(SENSORES) do esSensor[r] = true end
for _, r in ipairs(SENSORES_WIFI) do esSensor[r] = true end
local FOTO = {}
local HILO_SENSORES = [[
local raiz, nombre, lista = ...
require("love.timer")
local canal = love.thread.getChannel(nombre)
local rutas = {}
for r in lista:gmatch("[^\n]+") do rutas[#rutas + 1] = r end
while true do
    local foto = {}
    for _, r in ipairs(rutas) do
        local f = io.open(raiz .. r, "r") or (raiz ~= "" and r:sub(1, 6) == "/proc/" and io.open(r, "r"))
        if f then foto[r] = f:read("*a") or ""; f:close(); foto["@t" .. r] = love.timer.getTime() end
    end
    canal:push(foto)
    love.timer.sleep(1)
end
]]
local canalesSensores = {}
local function arrancarSensores()
    for i, lista in ipairs({SENSORES, SENSORES_WIFI}) do
        local nombre = "pulso-sensores-" .. i
        love.thread.newThread(HILO_SENSORES):start(RAIZ, nombre, table.concat(lista, "\n"))
        canalesSensores[#canalesSensores + 1] = love.thread.getChannel(nombre)
    end
end
local function recibirSensores(esperar)
    for i, canal in ipairs(canalesSensores) do
        local f = canal:pop()
        if not f and esperar and i == 1 then f = canal:demand(1) end   -- al arrancar: hasta 1 s por la primera foto
        while f do
            for k, v in pairs(f) do FOTO[k] = v end
            if i == 2 then for _, r in ipairs(SENSORES_WIFI) do if f[r] == nil then FOTO[r] = nil end end end
            f = canal:pop()
        end
    end
end

local function leer(ruta)
    if esSensor[ruta] then return FOTO[ruta] end   -- de la última foto, nunca directo
    local f = io.open(RAIZ .. ruta, "r") or (RAIZ ~= "" and ruta:sub(1, 6) == "/proc/" and io.open(ruta, "r"))
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end
local function num(ruta) local t = leer(ruta); return t and tonumber(t:match("%-?%d+")) end
local function texto(ruta) local t = leer(ruta); return t and t:match("^%s*(.-)%s*$") end

local D = {nucleos = {}, uso = {}, discos = {}, red = {}, zram = {}}
local hist = {nucleo = {{}, {}, {}, {}}, usoNucleo = {{}, {}, {}, {}}, uso = {}, temp = {}, senal = {}, volt = {}, baja = {}, sube = {}}
local function empujar(t, v, n) t[#t + 1] = v; if #t > (n or 90) then table.remove(t, 1) end end
local statAntes = {}

local CPU = "/sys/devices/system/cpu/cpu"
do   -- límites del procesador (no cambian)
    local disp = texto(CPU .. "0/cpufreq/scaling_available_frequencies") or ""
    local mn, mx = math.huge, 0
    for f in disp:gmatch("%d+") do f = tonumber(f) / 1000; mn, mx = math.min(mn, f), math.max(mx, f) end
    D.minf = num(CPU .. "0/cpufreq/cpuinfo_min_freq") and num(CPU .. "0/cpufreq/cpuinfo_min_freq") / 1000 or (mn < math.huge and mn or 400)
    D.maxf = mx > 0 and mx or (num(CPU .. "0/cpufreq/cpuinfo_max_freq") or 1512000) / 1000
    D.fpiso = mn < math.huge and mn or D.minf   -- el escalón más bajo que de verdad usa (en la RG36H con dArkOS, 1008)
    if D.fpiso >= D.maxf then D.fpiso = D.minf end
    local g = GPU and texto(GPU .. "available_frequencies") or ""
    D.gmax = 0
    for f in g:gmatch("%d+") do D.gmax = math.max(D.gmax, tonumber(f) / 1e6) end
    if D.gmax == 0 then D.gmax = 520 end
end

local function leerSensores()
    -- núcleos: en línea, frecuencia y uso (de /proc/stat)
    local stat = leer("/proc/stat") or ""
    local usoTotal, n = 0, 0
    for i = 0, 3 do
        local online = i == 0 and 1 or (num(CPU .. i .. "/online") or 1)
        local f = num(CPU .. i .. "/cpufreq/scaling_cur_freq") or num(CPU .. "0/cpufreq/scaling_cur_freq") or 0
        local linea = stat:match("\ncpu" .. i .. " ([^\n]+)") or ""
        local campos = {}
        for v in linea:gmatch("%d+") do campos[#campos + 1] = tonumber(v) end
        local total, ocio = 0, (campos[4] or 0) + (campos[5] or 0)
        for k = 1, math.min(8, #campos) do total = total + campos[k] end
        local a = statAntes[i]
        local uso = 0
        if a and total > a[1] then uso = 1 - (ocio - a[2]) / (total - a[1]) end
        statAntes[i] = {total, ocio}
        D.nucleos[i + 1] = {mhz = online == 1 and f / 1000 or 0, activo = online == 1, uso = limitar(uso, 0, 1)}
        if online == 1 then usoTotal, n = usoTotal + limitar(uso, 0, 1), n + 1 end
        empujar(hist.nucleo[i + 1], D.nucleos[i + 1].mhz)
        empujar(hist.usoNucleo[i + 1], D.nucleos[i + 1].uso)
    end
    D.carga = n > 0 and usoTotal / n or 0
    empujar(hist.uso, D.carga)
    D.modo = texto(CPU .. "0/cpufreq/scaling_governor") or "?"
    -- temperaturas
    D.temp, D.gtemp = nil, nil
    for z = 0, 3 do
        local tipo = texto("/sys/class/thermal/thermal_zone" .. z .. "/type")
        local t = num("/sys/class/thermal/thermal_zone" .. z .. "/temp")
        if tipo and t then
            if tipo:match("gpu") then D.gtemp = t / 1000 elseif not D.temp then D.temp = t / 1000 end
        end
    end
    if D.temp then empujar(hist.temp, D.temp) end
    D.gpu = GPU and num(GPU .. "cur_freq") and num(GPU .. "cur_freq") / 1e6   -- nil si no hay
    D.dmc = (num("/sys/class/devfreq/dmc/cur_freq") or 0) / 1e6
    -- batería
    local B = BAT or "/sin-bateria/"
    D.hayBateria = BAT ~= nil and num(B .. "voltage_now") ~= nil
    D.pctMedidor = num(B .. "capacity") or 0
    D.pct = D.pct or D.pctMedidor          -- el propio lo pone actualizarBateria()
    D.mv = (num(B .. "voltage_now") or 0) / 1000
    D.ma = (num(B .. "current_now") or 0) / 1000
    D.estado = texto(B .. "status") or "?"
    D.cargador = false
    for _, r in ipairs(CARGADORES) do if num(r) == 1 then D.cargador = true end end
    empujar(hist.volt, D.mv, 180)
    -- memoria y ZRam
    local mem = leer("/proc/meminfo") or ""
    D.ramTotal = (tonumber(mem:match("MemTotal:%s+(%d+)")) or 0) / 1024
    D.ramLibre = (tonumber(mem:match("MemAvailable:%s+(%d+)")) or 0) / 1024
    local z = D.zram
    z.activa = (leer("/proc/swaps") or ""):match("zram0") ~= nil
    local mm = {}
    for v in (leer("/sys/block/zram0/mm_stat") or ""):gmatch("%d+") do mm[#mm + 1] = tonumber(v) end
    z.guardado, z.ocupa = (mm[1] or 0) / 1048576, (mm[3] or 0) / 1048576
    z.tam = (num("/sys/block/zram0/disksize") or 0) / 1048576
    -- red: señal
    local w = leer("/proc/net/wireless") or ""
    D.red.senal = tonumber(w:match((D.wifi or "wlan0"):gsub("%p", "%%%0") .. ":%s+%S+%s+%S+%s+(%-?%d+)"))
    if D.red.senal then empujar(hist.senal, D.red.senal) end
    -- red: tráfico (bytes por segundo de todas las interfaces menos lo, con la hora en que el hilo leyó el archivo)
    local dev, tdev = leer("/proc/net/dev"), FOTO["@t/proc/net/dev"]
    if dev and tdev and tdev ~= D.trafT then
        local rx, tx = 0, 0
        for nombre, resto in dev:gmatch("\n%s*([%w%._-]+):([^\n]*)") do
            if nombre ~= "lo" then
                local c = {}
                for v in resto:gmatch("%d+") do c[#c + 1] = tonumber(v) end
                rx, tx = rx + (c[1] or 0), tx + (c[9] or 0)
            end
        end
        if D.trafT and tdev > D.trafT and rx >= D.trafRx and tx >= D.trafTx then
            local dt = tdev - D.trafT
            D.red.baja, D.red.sube = (rx - D.trafRx) / dt, (tx - D.trafTx) / dt
            empujar(hist.baja, D.red.baja); empujar(hist.sube, D.red.sube)
        end
        D.trafT, D.trafRx, D.trafTx = tdev, rx, tx
        D.red.totalBaja, D.red.totalSube = rx, tx
    end
    -- pantalla y tiempo
    D.brillo = LUZ and num(LUZ .. "brightness") and num(LUZ .. "brightness") / math.max(1, num(LUZ .. "max_brightness") or 1)
    D.encendida = (tonumber((leer("/proc/uptime") or ""):match("^[%d%.]+")) or 0) / 60
end

-- Batería propia (2026-11-17). El medidor del sistema (RK817) no sirve: al encender cargando «adivina» (pasó de
-- 15 % a 77 %), llega a 100 % con la batería a la mitad, y al descargar se apaga marcando 15 %. Por eso el
-- porcentaje y los tiempos salen del registro de batería (bateria-registro):
--   descargando: mAh que quedan según el voltaje, sobre la última descarga terminada (curva.puntos[k].resta)
--   cargando: mAh que faltan según la última carga completa (curvaCarga): por voltaje mientras sube (hasta
--     4,10 V) y por corriente al final, cuando el voltaje se queda quieto y la corriente baja
-- Voltaje y corriente promediados ~30 s. Sin registro, se usa el medidor como antes.
local leerCurvas   -- se define con la pantalla Batería
local consumo, volt = {}, {}
local curva, curvaCarga    -- nil = sin leer; false = no hay en el registro
local function limitar01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function restaPorVoltaje(mv)
    local b = curva and curva.puntos
    if not b then return nil end
    if mv >= b[1].suave then   -- más arriba que donde empezó esa descarga: se completa hasta 4,15 V
        return b[1].resta + (CAPACIDAD - b[1].resta) * limitar01((mv - b[1].suave) / math.max(1, 4150 - b[1].suave))
    end
    for k = 2, #b do
        if b[k].suave <= mv then   -- primer punto que bajó de ese voltaje: interpola con el anterior
            local a, c = b[k - 1], b[k]
            local f = (a.suave - mv) / math.max(1, a.suave - c.suave)
            return a.resta + (c.resta - a.resta) * f
        end
    end
    return 0
end
local function faltaPorCarga(mv, ma)
    -- devuelve mAh y minutos que faltan para llenarse según la carga completa de referencia
    local b = curvaCarga and curvaCarga.puntos
    if not b then return nil end
    local function mezcla(a, c, f) return a.falta + (c.falta - a.falta) * f, a.min + (c.min - a.min) * f end
    if mv < 4100 then
        if mv <= b[1].suave then   -- más abajo que donde empezó la referencia: se completa hasta 3,65 V (vacía)
            local extra = (CAPACIDAD - b[1].falta) * limitar01((b[1].suave - mv) / math.max(1, b[1].suave - 3650))
            return b[1].falta + extra, b[1].min + extra / math.max(100, ma) * 60
        end
        for k = 2, #b do
            if b[k].suave >= mv then
                local a, c = b[k - 1], b[k]
                return mezcla(a, c, (mv - a.suave) / math.max(1, c.suave - a.suave))
            end
        end
        return 0, 0
    end
    local prev   -- tramo final: el primer punto (sobre 4,10 V) donde la corriente ya bajó a la de ahora
    for k = 1, #b do
        local c = b[k]
        if c.suave >= 4100 then
            if c.corr <= ma then
                if not prev then return c.falta, c.min end
                return mezcla(prev, c, (prev.corr - ma) / math.max(1, prev.corr - c.corr))
            end
            prev = c
        end
    end
    return 0, 0
end
-- «Desde la carga» se sigue cada segundo (no solo al dibujar): si se carga con la app abierta, vuelve a contar desde
-- que se desconecta. Si la última fila del registro es de un arranque anterior y la batería está bastante más
-- llena que entonces (+100 mV), se cargó con la consola apagada (o con el registro apagado): cuenta desde este arranque.
local cargabaAntes, revisadoArranque
local function seguirCarga()
    local ahora = os.time()
    if D.cargador then cargabaAntes = true; return end
    if cargabaAntes then D.desdeCarga = {t = ahora, on = 0, ultima = ahora, mv = D.mv}; cargabaAntes = false end
    local dc = D.desdeCarga
    if dc and not revisadoArranque and D.mv and D.mv > 0 then
        revisadoArranque = true
        local arranque = ahora - (D.encendida or 0) * 60
        if dc.ultima < arranque - 90 and dc.mv and D.mv > dc.mv + 100 then
            D.desdeCarga = {t = arranque, on = 0, ultima = arranque, mv = D.mv}
        end
    end
end
local function actualizarBateria()
    -- una vez por segundo, después de leer los sensores
    empujar(consumo, D.ma, 30)
    empujar(volt, D.mv, 30)
    local s, sv = 0, 0
    for _, v in ipairs(consumo) do s = s + v end
    for _, v in ipairs(volt) do sv = sv + v end
    local prom, mv = s / math.max(1, #consumo), sv / math.max(1, #volt)
    if curva == nil then curva, curvaCarga = leerCurvas(); curva = curva or false; curvaCarga = curvaCarga or false end
    seguirCarga()
    D.que, D.min, D.por = nil, nil, nil
    if D.estado == "Discharging" and prom < -40 then
        local mah = restaPorVoltaje(mv)
        if mah then
            D.pct = math.floor(limitar01(mah / CAPACIDAD) * 100 + 0.5)
            D.que, D.min, D.por = "quedan", mah / -prom * 60, "voltaje"
        else
            D.pct = D.pctMedidor
            D.que, D.min = "quedan", D.pct / 100 * CAPACIDAD / -prom * 60
        end
    elseif D.cargador and mv >= 4140 and prom < 200 then
        D.pct, D.que, D.min = 100, nil, nil      -- llena de verdad
    elseif D.cargador and prom > 40 then
        local falta, min = faltaPorCarga(mv, prom)
        if falta then
            D.pct = math.floor(limitar01(1 - falta / CAPACIDAD) * 100 + 0.5)
            D.que, D.min, D.por = "llena en", min, "carga"
        else
            D.pct = D.pctMedidor
            if D.pct < 100 then D.que, D.min = "llena en", (100 - D.pct) / 100 * CAPACIDAD / prom * 60 end
        end
    elseif not D.pct then
        D.pct = D.pctMedidor
    end
end
local function estimar() return D.que, D.min, D.por end
local function textoQue(que, min) return que == "quedan" and T("quedan %s", duracion(min)) or T("llena en %s", duracion(min)) end
-- Tiempos para el panel TIEMPOS y el tablero. «Desde la carga» parte del registro (leído al abrir) y sigue en vivo;
-- si se carga con la app abierta, vuelve a contar desde que se desconecta.
local function tiempos()
    local ahora = os.time()
    local arranque = ahora - (D.encendida or 0) * 60
    if D.cargador then return {sesion = D.encendida, arranque = arranque, cargando = true} end
    local dc, on, real = D.desdeCarga, nil, nil
    if dc then
        -- lo registrado hasta la última fila, más lo de ahora: desde esa fila si es de esta sesión, si no la sesión entera
        on = dc.on + (dc.ultima >= arranque - 90 and (ahora - dc.ultima) / 60 or (D.encendida or 0))
        real = (ahora - dc.t) / 60
    end
    return {sesion = D.encendida, arranque = arranque, on = on, real = real, desde = dc and dc.t}
end

-- ── hilos: ayudante y acciones ──
local HILO = [[
local orden, nombre = ...
local canal = love.thread.getChannel(nombre)
local f = io.popen(orden .. " 2>&1; echo __FIN__$?")
for l in f:lines() do canal:push(l) end
f:close()
]]
local tareas, nTarea = {}, 0
local function correr(orden, alFin, alLinea, limite)
    nTarea = nTarea + 1
    local nombre = "pulso-" .. nTarea
    local t = {hilo = love.thread.newThread(HILO), canal = love.thread.getChannel(nombre), lineas = {}, alFin = alFin, alLinea = alLinea,
               t0 = love.timer.getTime(), limite = limite or 120}
    t.hilo:start(orden, nombre)
    tareas[#tareas + 1] = t
end
local function atenderTareas()
    for i = #tareas, 1, -1 do
        local t = tareas[i]
        local l = t.canal:pop()
        while l do
            local resto, cod = l:match("^(.-)__FIN__(%d+)$")
            if resto and resto ~= "" then t.lineas[#t.lineas + 1] = resto; if t.alLinea then t.alLinea(resto) end end
            if cod then table.remove(tareas, i); if t.alFin then t.alFin(tonumber(cod), t.lineas) end; break end
            t.lineas[#t.lineas + 1] = l
            if t.alLinea then t.alLinea(l) end
            l = t.canal:pop()
        end
        if tareas[i] == t and love.timer.getTime() - t.t0 > t.limite then   -- red de seguridad: nunca esperar para siempre
            table.remove(tareas, i)
            if t.alFin then t.alFin(124, {"La orden tardó demasiado; revisa si se hizo."}) end
        elseif tareas[i] == t and t.hilo:getError() then table.remove(tareas, i); if t.alFin then t.alFin(99, {t.hilo:getError()}) end end
    end
end

local ayudanteCorriendo = false
local function decodificar(s) return (s:gsub("\\x(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local avisar   -- se define con los avisos (más abajo); el ayudante la usa
local ultimoCompleto = -1e9
-- rapido = la vuelta de cada 5 s (sin lo que casi no cambia); el completo va al abrir, cada minuto y tras una acción
local function preguntarAyudante(rapido)
    if ayudanteCorriendo then return end
    if rapido and love.timer.getTime() - ultimoCompleto >= 60 then rapido = false end
    if not rapido then ultimoCompleto = love.timer.getTime() end
    ayudanteCorriendo = true
    correr(AYUDANTE .. (rapido and " rapido" or ""), function(cod, lineas)
        if cod == 124 then ayudanteCorriendo = false return end
        ayudanteCorriendo = false
        D.discos = {}
        local completo = false
        for _, l in ipairs(lineas) do if l == "COMPLETO=1" then completo = true end end
        if completo then D.registroServicio, D.zram.servicio = nil, nil end
        local r = {ssid = nil, freq = nil, enlace = nil, ip = nil, router = nil, senal = D.red.senal,
            baja = D.red.baja, sube = D.red.sube, totalBaja = D.red.totalBaja, totalSube = D.red.totalSube, banda = not completo and D.red.banda or nil}
        for _, l in ipairs(lineas) do
            local k, v = l:match("^(%u[%u_]*)=(.*)$")
            if k == "DISCO" then
                local m, usado, total = v:match("^(.-)|(%d+)|(%d+)$")
                if m then D.discos[m] = {usado = tonumber(usado) / 1048576, total = tonumber(total) / 1048576} end
            elseif k == "SSID" then r.ssid = decodificar(v):match("^%s*(.-)%s*$")
            elseif k == "FREQ" then r.freq = tonumber(v)
            elseif k == "ENLACE" then r.enlace = tonumber(v)
            elseif k == "IP" then r.ip = v
            elseif k == "ROUTER" then r.router = v
            elseif k == "ZRAM_ARRANQUE" then D.zram.arranque = v == "1"
            elseif k == "ZRAM_TAM" then D.zram.elegido = tonumber(v)
            elseif k == "REGISTRO" then D.registro = v == "1"
            elseif k == "REGISTRO_SERVICIO" then D.registroServicio = v      -- pulso36 · otro · no
            elseif k == "REGISTRO_DIR" and not REGISTRO_FIJO and conBarra(v) ~= REGISTRO then
                REGISTRO = conBarra(v); curva = nil                     -- se vuelve a leer la curva desde ahí
            elseif k == "ZRAM_GESTOR" then D.zram.gestor = v ~= "" and v or nil
            elseif k == "ZRAM_CONF_MB" then D.zram.confMb = tonumber(v)          -- lo que dejó configurado el ZRam Manager
            elseif k == "ZRAM_CONF_ALGO" then D.zram.confAlgo = v ~= "" and v or nil
            elseif k == "ZRAM_SIS_ARRANQUE" then D.zram.sisArranque = v == "1"
            elseif k == "ZRAM_CHOQUE" then D.zram.choque = v == "1"                 -- la de Pulso y la del sistema a la vez
            elseif k == "ZRAM" then D.zram.servicio = v                     -- pulso36 · sistema · no · nada
            elseif k == "WIFI" then D.wifi = v
            elseif k == "WIFI_IGUAL" then r.igual = true
            elseif k == "BANDA" then r.banda = v
            elseif k == "SSH_SERVICIO" then D.hayssh = v == "1"
            elseif k == "SUDO" then
                D.sudo = v == "1"
                if not D.sudo and not D.avisoSudo then
                    D.avisoSudo = true
                    avisar(T"Esta consola no deja cambiar el sistema: Pulso 36 solo mostrará datos.", C.alerta, 6)
                end
            elseif k == "VIGILA" then D.vigila = v == "1"
            elseif k == "SERVICIOS" then D.servicios = {ssh = v:sub(1, 1) == "1", samba = v:sub(2, 2) == "1", fb = v:sub(3, 3) == "1"}
            elseif k == "TOP" then local p, c = v:match("^(.-)|([%d%.]+)$"); D.top = p and {p, tonumber(c)} end
        end
        -- sin nmcli en esta vuelta (dArkOS): lo último leído vale mientras siga la misma IP; sin IP se borra
        if r.igual then
            if r.ip and r.ip == D.red.ip then r.ssid, r.freq, r.enlace = D.red.ssid, D.red.freq, D.red.enlace
            elseif r.ip then ultimoCompleto = -1e9 end   -- IP nueva (otra red): la próxima vuelta va completa
            r.igual = nil
        end
        D.red = r
        -- una ZRam encendida que no es la nuestra la maneja otro: no se ofrece instalar otra encima
        if not completo then return end
        if D.zram.servicio == "no" and D.zram.activa then D.zram.servicio = "sistema" end
        -- sin permisos de administrador no se ofrece instalar nada
        if D.sudo == false then
            if D.zram.servicio == "no" then D.zram.servicio = "nada" end
            if D.registroServicio == "no" then D.registroServicio = "sinpermiso" end
        end
    end)
end

-- ── procesos: /proc/<pid>/stat leído dos veces; la diferencia es lo que consumen ahora ──
local PROTEGIDOS = {systemd = true, emulationstatio = true, sshd = true, gptokeyb = true, ["love.aarch64"] = true,
    love = true, ["dbus-daemon"] = true, sudo = true, NetworkManager = true, wpa_supplicant = true}
local NOMBRES_PROC = {emulationstatio = T"Menú (EmulationStation)", retroarch = "RetroArch", sshd = "SSH", smbd = "Samba",
    nmbd = T"Samba (nombres)", filebrowser = "FileBrowser", NetworkManager = T"Red (NetworkManager)", wpa_supplicant = "Wifi",
    ["systemd-journal"] = T"Registro del sistema", systemd = T"Sistema (systemd)", gptokeyb = T"Controles (gptokeyb)",
    rclone = "rclone", ["systemd-resolve"] = "DNS", ["systemd-timesyn"] = T"Hora (sincronización)",
    ["sshd-session"] = T"SSH (conexión abierta)",
    checknswitchfor = T"Audio USB (dArkOS)"}   -- checknswitchforusbdac.sh: el sistema corta el nombre a 15 letras
local NOMBRES_SCRIPT = {["aviso-bateria.py"] = T"Aviso de batería"}   -- scripts en Python o bash, por su archivo
local PR = {antes = {}, lista = nil, total = 0, leyendo = false, tAntes = nil}
local function basename(r) return (r:match("([^/]+)$") or r) end
local function nombreProceso(pid, comm)
    local cmd = (leer("/proc/" .. pid .. "/cmdline") or ""):gsub("%z+$", "")
    local args = {}
    for a in cmd:gmatch("[^%z]+") do args[#args + 1] = a end
    if comm == "retroarch" then
        local juego = args[#args]
        if juego and not juego:match("^%-") and juego:match("%.") then return "RetroArch · " .. basename(juego):gsub("%.[^.]+$", "") end
        return "RetroArch"
    end
    if comm:match("^love") then
        for _, a in ipairs(args) do if a:match("pulso36") then return T"Pulso 36 (esta app)" end end
        return "LÖVE · " .. basename(args[#args] or "")
    end
    if comm == "systemd" and args[2] == "--user" then return T"Sesión (systemd)" end
    if comm:match("^python") or comm == "bash" or comm == "sh" then
        for k = 2, #args do
            if not args[k]:match("^%-") then local b = basename(args[k]); return NOMBRES_SCRIPT[b] or b end
        end
    end
    return NOMBRES_PROC[comm] or comm
end
local function procesarProcesos(lineas)
    local ahora = love.timer.getTime()
    local dt = PR.tAntes and (ahora - PR.tAntes) or nil
    local nuevos, lista = {}, {}
    for _, l in ipairs(lineas) do
        local pid, comm, resto = l:match("^(%d+) %((.*)%) (.*)$")
        if pid then
            local f = {}
            for v in resto:gmatch("%S+") do f[#f + 1] = v end
            local ticks = (tonumber(f[12]) or 0) + (tonumber(f[13]) or 0)
            local rss = (tonumber(f[22]) or 0) * 4 / 1024
            nuevos[pid] = ticks
            if rss > 0 then   -- sin memoria propia = hilo del núcleo, no un programa
                local a = PR.antes[pid]
                local cpu = (dt and a) and math.max(0, (ticks - a) / (dt * 100) * 100 / 4) or 0
                lista[#lista + 1] = {pid = tonumber(pid), comm = comm, cpu = cpu, ram = rss}
            end
        end
    end
    table.sort(lista, function(a, b) if math.abs(a.cpu - b.cpu) > 0.05 then return a.cpu > b.cpu end return a.ram > b.ram end)
    for k, q in ipairs(lista) do
        if k <= 14 then
            q.nombre = nombreProceso(q.pid, q.comm)
            local st = leer("/proc/" .. q.pid .. "/status") or ""
            local uid = tonumber(st:match("Uid:%s+(%d+)")) or 0
            q.protegido = PROTEGIDOS[q.comm] or q.comm:match("^love") ~= nil or uid < 1000 or q.pid == 1
        end
    end
    PR.antes, PR.tAntes, PR.total = nuevos, ahora, #lista
    if dt then PR.lista = lista end
end
local function leerProcesos()
    if PR.leyendo then return end
    PR.leyendo = true
    -- PULSO_PROCESOS (desarrollo): otra orden que imprima líneas como /proc/<pid>/stat, para las capturas
    correr(os.getenv("PULSO_PROCESOS") or "cd /proc && cat [0-9]*/stat 2>/dev/null",
        function(_, lineas) PR.leyendo = false; procesarProcesos(lineas) end)
end

-- ── sonidos ──
local function tono(frecuencias, dur, vol)
    local sr = 22050
    local n = math.floor(sr * dur)
    local sd = love.sound.newSoundData(n, sr, 16, 1)
    for i = 0, n - 1 do
        local t, env, v = i / sr, (1 - i / n) ^ 2, 0
        for _, f in ipairs(frecuencias) do v = v + math.sin(2 * math.pi * f * t) / #frecuencias end
        sd:setSample(i, v * env * vol)
    end
    return love.audio.newSource(sd, "static")
end
local function sonar(n) if S[n] then S[n]:clone():play() end end

-- ── piezas de dibujo ──
-- fondo y líneas de barrido: se dibujan una vez por tema en un lienzo y luego se pegan (antes: ~1400 rectángulos por cuadro)
local cacheFondo, cacheBarrido, cacheTema = nil, nil, nil
local function prepararLienzos()
    if cacheTema == tema then return end
    cacheTema = tema
    cacheFondo = cacheFondo or lg.newCanvas(W, H)
    lg.setCanvas(cacheFondo); lg.clear(C.fondo)
    color(C.trama)
    for y = 0, H, 16 do for x = (y / 16) % 2 * 8, W, 16 do px(x, y, 2, 2) end end
    lg.setCanvas()
    if C.barrido then
        cacheBarrido = cacheBarrido or lg.newCanvas(W, H)
        lg.setCanvas(cacheBarrido); lg.clear(0, 0, 0, 0)
        lg.setColor(0, 0, 0, 1)
        for y = 0, H, 3 do px(0, y, W, 1) end
        lg.setCanvas()
    end
end
local function fondo()
    prepararLienzos()
    lg.setColor(1, 1, 1); lg.draw(cacheFondo)
end
local function barrido()
    if not C.barrido then return end
    lg.setColor(1, 1, 1, 0.22); lg.draw(cacheBarrido)
    lg.setColor(1, 1, 1, 0.025 + 0.015 * math.sin(reloj * 1.7))
    px(0, (reloj * 90) % (H + 60) - 60, W, 60)
end
local function panel(x, y, w, h, titulo, elegido)
    color(elegido and C.marca or C.panel, 0.92); lg.rectangle("fill", x, y, w, h, 6, 6)
    color(elegido and C.acento or C.borde, elegido and (0.7 + 0.3 * math.sin(reloj * 4)) or 1)
    lg.setLineWidth(elegido and 2 or 1); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    if titulo then lg.setFont(F.chica); color(C.tenue); lg.print(titulo, x + 12, y + 8) end
end
local function barra(x, y, w, h, frac, c)
    color(C.trama); px(x, y, w, h)
    local lleno = math.floor((w - 2) * limitar(frac, 0, 1))
    for i = 0, lleno - 2, 4 do color(c, 0.65 + 0.35 * ((i / 4) % 2)); px(x + 1 + i, y + 1, 3, h - 2) end
end
local function nivel(frac) return frac > 0.85 and C.alerta or frac > 0.7 and C.oro or C.acento end
local function grafica(x, y, w, h, datos, mn, mx, c, total, relleno)   -- relleno: opacidad del área (0 = solo línea)
    total = total or 90
    if #datos < 2 then return end
    local desde = math.max(1, #datos - total + 1)
    local function pos(i) return x + w - (#datos - i) / (total - 1) * w end
    if relleno ~= 0 then
        color(c, relleno or 0.16)
        for i = desde, #datos do
            local v = limitar((datos[i] - mn) / (mx - mn), 0, 1)
            px(math.floor(pos(i) / 2) * 2, y + h - v * h, 2, v * h)
        end
    end
    if relleno and relleno > 0.16 then return end   -- área sola, sin línea
    color(c)
    for i = desde + 1, #datos do
        local a = limitar((datos[i - 1] - mn) / (mx - mn), 0, 1)
        local b = limitar((datos[i] - mn) / (mx - mn), 0, 1)
        for k = 0, 3 do
            local t = k / 3
            px(math.floor((pos(i - 1) + (pos(i) - pos(i - 1)) * t) / 2) * 2,
               math.floor((y + h - (a + (b - a) * t) * h) / 2) * 2, 2, 2)
        end
    end
end
local function suavizar(t, n)   -- promedio móvil de los últimos n valores (la frecuencia salta casi cada segundo)
    local r, suma = {}, 0
    for i = 1, #t do
        suma = suma + t[i]
        if i > n then suma = suma - t[i - n] end
        r[i] = suma / math.min(i, n)
    end
    return r
end
local function velocidad(b)   -- bytes por segundo, a lo humano
    if not b then return "—" end
    if b < 1000 then return math.floor(b + 0.5) .. " B/s" end
    if b < 1e6 then return coma(string.format(b < 1e4 and "%.1f" or "%.0f", b / 1000)) .. " KB/s" end
    return coma(string.format(b < 1e7 and "%.1f" or "%.0f", b / 1e6)) .. " MB/s"
end
local function cantidad(b)
    if not b then return "—" end
    if b < 1e6 then return coma(string.format("%.0f", b / 1000)) .. " KB" end
    if b < 1e9 then return coma(string.format("%.1f", b / 1e6)) .. " MB" end
    return coma(string.format("%.2f", b / 1e9)) .. " GB"
end
local ESCALAS = {2e3, 5e3, 1e4, 2e4, 5e4, 1e5, 2e5, 5e5, 1e6, 2e6, 5e6, 1e7, 2e7, 5e7}
local function graficaTrafico(x, y, w, h, total)   -- bajada y subida con la misma escala, que se ajusta sola
    local mx = 0
    for _, s in ipairs({hist.baja, hist.sube}) do
        for i = math.max(1, #s - (total or 90) + 1), #s do mx = math.max(mx, s[i]) end
    end
    local tope = ESCALAS[#ESCALAS]
    for _, e in ipairs(ESCALAS) do if mx <= e then tope = e; break end end
    grafica(x, y, w, h, hist.baja, 0, tope, C.acento, total)
    grafica(x, y, w, h, hist.sube, 0, tope, C.oro, total)
    return tope
end
local function boton(x, y, letra, txt)
    lg.setFont(F.chica)
    local bw = math.max(16, F.chica:getWidth(letra) + 10)
    color(C.borde); lg.rectangle("fill", x, y, bw, 16, 8, 8)
    color(C.crema); lg.printf(letra, x, y + 1, bw, "center")
    color(C.tenue); lg.print(txt, x + bw + 5, y + 1)
    return x + bw + 5 + F.chica:getWidth(txt) + 14
end
local function ayudas(l) local x = 16; for _, p in ipairs(l) do x = boton(x, H - 26, p[1], p[2]) end end
local function sello(x, y, c)
    color(c); px(x, y + 4, 2, 2); px(x + 2, y + 6, 2, 2); px(x + 4, y + 4, 2, 2); px(x + 6, y + 2, 2, 2); px(x + 8, y, 2, 2)
end
local function puntos(x, y, c)
    for i = 0, 2 do color(c or C.oro, (math.floor(reloj * 4) % 3 == i) and 1 or 0.3); px(x + i * 7, y, 4, 4) end
end
local function senalBarras(x, y, esc, dbm)
    local q = dbm and limitar((dbm + 90) / 55, 0, 1) or 0
    for i = 0, 3 do
        color(i < math.ceil(q * 4) and C.acento or C.trama)
        px(x + i * 9 * esc, y + (21 - i * 7) * esc, 6 * esc, (8 + i * 7) * esc)
    end
end
local function calidad(dbm)
    if not dbm then return T"sin datos" end
    return dbm >= -55 and T"excelente" or dbm >= -67 and T"buena" or dbm >= -75 and T"regular" or T"débil"
end

-- el latido: corazón pixelado y un electrocardiograma que se acelera con la carga
local CORAZON = {"0110110", "1111111", "1111111", "0111110", "0011100", "0001000"}
local fase = 0
local function corazon(x, y, esc)
    local b = math.max(0, math.sin(fase * math.pi * 2)) ^ 6
    local e = esc * (1 + 0.18 * b)
    color(C.pulso)
    for fy, fila in ipairs(CORAZON) do
        for fx = 1, #fila do
            if fila:sub(fx, fx) == "1" then px(x + (fx - 4) * e, y + (fy - 3.5) * e, math.ceil(e), math.ceil(e)) end
        end
    end
    color({1, 1, 1}, 0.7); px(x - 2 * e, y - 2 * e, math.ceil(e), math.ceil(e))
end
local function latido(t)
    t = t % 1
    if t < 0.10 then return 0.15 * math.sin(t / 0.10 * math.pi) end
    if t < 0.16 then return 0 end
    if t < 0.19 then return -0.25 * (t - 0.16) / 0.03 end
    if t < 0.23 then return -0.25 + 1.25 * (t - 0.19) / 0.04 end
    if t < 0.27 then return 1.0 - 1.35 * (t - 0.23) / 0.04 end
    if t < 0.30 then return -0.35 + 0.35 * (t - 0.27) / 0.03 end
    if t < 0.45 then return 0 end
    if t < 0.62 then return 0.28 * math.sin((t - 0.45) / 0.17 * math.pi) end
    return 0
end
local function ecg(x, y, w, h)
    for i = 0, w, 2 do
        color(C.pulso, 0.25 + 0.75 * (i / w))
        px(x + i, math.floor((y + h * 0.6 - latido((i / w) * 2.2 + fase) * h * 0.55) / 2) * 2, 2, 2)
    end
end

-- avisos que aparecen y se van
local toast
avisar = function(t, c, dur) toast = {texto = t, color = c or C.acento, t0 = reloj, dur = dur or 3} end
local pregunta
local function preguntar(titulo, txt, si) pregunta = {titulo = titulo, texto = txt, si = si, t0 = reloj} end

-- ── escenas ──
local E, escena = {}, nil
local transicion = 1
local function ir(nombre) escena = nombre; transicion = 0; if E[nombre].entrar then E[nombre].entrar() end end

local function cabecera(sub)
    lg.setFont(F.titulo); color(C.acento)
    lg.print("Pulso 36", 18, 12)
    lg.setFont(F.normal); color(C.crema)
    lg.printf(os.date("%H:%M"), W - 140, 14, 122, "right")
    lg.setFont(F.chica); color(C.tenue)
    lg.printf(sub or T("encendida %s", duracion(D.encendida)), W - 200, 34, 182, "right")
end

-- Tablero
E.tablero = {sel = 1}
local DESTINOS = {"bateria", "procesador", "memoria", "almacenamiento", "red", "procesos"}
local function pilaBateria(x, y, esc)
    local fr = D.pct / 100
    color(C.crema); lg.rectangle("line", x + 0.5, y + 0.5, 62 * esc, 30 * esc, 3, 3); px(x + 63 * esc, y + 9 * esc, 4 * esc, 12 * esc)
    local cargando = D.estado == "Charging"
    local ver = cargando and math.min(1, fr + ((reloj * 0.6) % 1) * (1 - fr)) or fr
    for i = 0, math.floor(54 * esc * ver) - 1, 6 * esc do
        color(nivel(1 - fr), (cargando and i >= 54 * esc * fr) and 0.4 or 0.85)
        px(x + 4 * esc + i, y + 4 * esc, 4 * esc, 23 * esc)
    end
    if cargando then   -- rayito
        color(C.oro)
        local rx, ry = x + 26 * esc, y + 6 * esc
        px(rx + 6 * esc, ry, 4 * esc, 6 * esc); px(rx + 2 * esc, ry + 6 * esc, 10 * esc, 3 * esc); px(rx + 2 * esc, ry + 9 * esc, 4 * esc, 7 * esc)
    end
end
function E.tablero.dibujar()
    cabecera()
    local sel = E.tablero.sel
    local gx, gy, tw, th = 16, 64, 196, 178
    local function caja(i) return gx + ((i - 1) % 3) * (tw + 10), gy + math.floor((i - 1) / 3) * (th + 10) end

    -- 1 batería
    local x, y = caja(1)
    panel(x, y, tw, th, T"BATERÍA", sel == 1)
    pilaBateria(x + 14, y + 34, 1)
    lg.setFont(F.grande); color(C.crema); lg.print(D.hayBateria == false and "—" or (D.pct .. "%"), x + 92, y + 32)
    lg.setFont(F.chica); color(C.tenue)
    lg.print(string.format("%s V · %d mA", coma(string.format("%.2f", D.mv / 1000)), math.floor(math.abs(D.ma) + 0.5)), x + 14, y + 76)
    local est = ({Charging = T"Cargando", Discharging = T"Descargando", Full = T"Llena", ["Not charging"] = T"Conectada, sin cargar"})[D.estado] or D.estado
    lg.print(est, x + 14, y + 94)
    local que, min = estimar()
    lg.setFont(F.normal); color(C.oro)
    if que == "quedan" and min < 5 then lg.print(T"menos de 5 min", x + 14, y + 118)
    else lg.print(que and textoQue(que, min) or T"calculando…", x + 14, y + 118) end
    lg.setFont(F.chica)
    if D.vigila then color(C.oro, 0.7 + 0.3 * math.sin(reloj * 3)); lg.print(T"se apagará al llenarse", x + 14, y + 138)
    else
        local ti = tiempos()
        color(C.tenue)
        lg.print(ti.on and recortar(F.chica, T("desde la carga: %s", duracion(ti.on)), tw - 28) or (que == "quedan" and T"con tu consumo de ahora" or ""), x + 14, y + 138)
    end

    -- 2 procesador
    x, y = caja(2)
    panel(x, y, tw, th, T"PROCESADOR", sel == 2)
    local activos, mx = 0, 0
    for i, n in ipairs(D.nucleos) do
        local cx, hh = x + 14 + (i - 1) * 26, 70
        color(C.trama); px(cx, y + 30, 18, hh)
        if n.activo then
            activos, mx = activos + 1, math.max(mx, n.mhz)
            -- alto = uso del núcleo; color = escalón de frecuencia (verde en el más bajo, dorado arriba)
            local alto = math.floor(hh * limitar(n.uso, 0.05, 1) / 4) * 4
            local cf = mezcla(C.acento, C.oro, (n.mhz - D.fpiso) / math.max(1, D.maxf - D.fpiso))
            for k = 0, alto - 4, 4 do color(cf, 0.9); px(cx + 2, y + 30 + hh - k - 3, 14, 3) end
        else
            color(C.borde); px(cx + 4, y + 30 + hh / 2, 10, 2)
        end
        lg.setFont(F.chica); color(n.activo and C.tenue or C.borde); lg.printf(tostring(i), cx, y + 104, 18, "center")
    end
    lg.setFont(F.normal); color(C.crema); lg.print(math.floor(mx), x + 124, y + 32)
    lg.setFont(F.chica); color(C.tenue)
    lg.print(T"MHz máx", x + 124, y + 50)
    lg.print(T("%s de 4", activos), x + 124, y + 74)
    lg.print(T"activos", x + 124, y + 90)
    lg.setFont(F.normal); color(D.temp and D.temp > 65 and C.alerta or C.oro)
    local tTxt = D.temp and (string.format("%.0f °C", D.temp)) or "— °C"
    lg.print(tTxt, x + 14, y + 128)
    lg.setFont(F.chica); color(C.tenue)
    lg.print(T"procesador", x + 22 + F.normal:getWidth(tTxt), y + 132)
    lg.print(recortar(F.chica, T("carga %s%% · %s", math.floor(D.carga * 100 + 0.5), D.modo), tw - 28), x + 14, y + 150)

    -- 3 memoria
    x, y = caja(3)
    panel(x, y, tw, th, T"MEMORIA", sel == 3)
    local libre = math.floor(D.ramLibre + 0.5)
    local frRam = 1 - D.ramLibre / math.max(1, D.ramTotal)
    local pctRam = math.floor(frRam * 100 + 0.5) .. " %"
    lg.setFont(F.grande); color(nivel(frRam) == C.acento and C.crema or nivel(frRam)); lg.print(pctRam, x + 14, y + 26)
    lg.setFont(F.chica); color(C.tenue); lg.print(T"en uso", x + 20 + F.grande:getWidth(pctRam), y + 40)
    barra(x + 14, y + 62, tw - 28, 10, frRam, nivel(frRam))
    lg.print(T("%s MB libres de %s", libre, math.floor(D.ramTotal + 0.5)), x + 14, y + 76)
    local z = D.zram
    if z.activa then
        lg.setFont(F.normal); color(C.acento)
        lg.print("ZRam +" .. math.floor(z.guardado - z.ocupa + 0.5) .. " MB", x + 14, y + 100)
        lg.setFont(F.chica); color(C.tenue)
        local ratio = z.ocupa > 0 and z.guardado / z.ocupa or 0
        lg.print(z.ocupa >= 1 and recortar(F.chica, string.format(T"%d MB en %d MB (%s:1)", z.guardado + 0.5, z.ocupa + 0.5, coma(string.format("%.1f", ratio))), tw - 28) or T"encendida, sin uso todavía", x + 14, y + 118)
        barra(x + 14, y + 140, tw - 28, 10, z.guardado / math.max(1, z.tam), C.oro)
    else
        local s = z.servicio
        lg.setFont(F.normal); color(C.tenue); lg.print(s == "no" and T"Sin ZRam" or s == "nada" and T"Sin ZRam" or T"ZRam apagada", x + 14, y + 100)
        lg.setFont(F.chica)
        lg.print(s == "pulso36" and T"A para encenderla" or s == "no" and T"A para instalarla" or s == "sistema" and (z.gestor and T("la maneja %s", z.gestor) or T"la maneja el sistema") or "", x + 14, y + 118)
    end

    -- 4 almacenamiento
    x, y = caja(4)
    panel(x, y, tw, th, T"ALMACENAMIENTO", sel == 4)
    local lista = {{T"Sistema", D.discos["/"]}, {T"Juegos (SD)", D.discos[ROMS]}}
    for i, d in ipairs(lista) do
        local yy = y + 30 + (i - 1) * 66
        lg.setFont(F.normal); color(C.crema); lg.print(d[1], x + 14, yy)
        if d[2] then
            local fr = d[2].usado / d[2].total
            barra(x + 14, yy + 22, tw - 28, 12, fr, nivel(fr))
            lg.setFont(F.chica); color(fr > 0.85 and C.alerta or C.tenue)
            lg.print(coma(string.format(T"%.1f GB libres · %d %% usado", d[2].total - d[2].usado, math.floor(fr * 100 + 0.5))), x + 14, yy + 40)
        else puntos(x + 14, yy + 28) end
    end

    -- 5 red
    x, y = caja(5)
    panel(x, y, tw, th, T"RED", sel == 5)
    local r = D.red
    senalBarras(x + 14, y + 33, 1, r.senal)
    lg.setFont(F.normal); color(C.crema)
    lg.print(recortar(F.normal, r.ssid or (r.ip and T"conectada" or T"sin Wifi"), tw - 72), x + 58, y + 30)
    lg.setFont(F.chica); color(C.tenue)
    local banda = r.freq and (r.freq >= 5000 and "5 GHz" or T"2,4 GHz") or "—"
    lg.print(banda .. (r.senal and (" · " .. r.senal .. " dBm") or ""), x + 58, y + 48)
    lg.setFont(F.normal); color(C.oro); lg.print(r.ip or T"sin IP", x + 14, y + 80)
    lg.setFont(F.chica); color(C.tenue); lg.print(T"IP de la consola", x + 14, y + 98)
    lg.setFont(F.chica); color(C.acento); lg.print(T("baja %s", velocidad(r.baja)), x + 14, y + 112)
    color(C.oro); lg.printf(T("sube %s", velocidad(r.sube)), x + 14, y + 112, tw - 28, "right")
    graficaTrafico(x + 14, y + 130, tw - 28, 28)

    -- 6 procesos
    x, y = caja(6)
    panel(x, y, tw, th, T"PROCESOS", sel == 6)
    if PR.lista then
        for k = 1, math.min(4, #PR.lista) do
            local q = PR.lista[k]
            local yy = y + 28 + (k - 1) * 30
            lg.setFont(F.chica); color(k == 1 and C.crema or C.tenue)
            lg.print(recortar(F.chica, (q.nombre:gsub(" %b()$", "")), tw - 76), x + 14, yy)   -- sin el paréntesis: el nombre completo va en Procesos
            color(q.cpu > 50 and C.alerta or C.oro); lg.printf(math.floor(q.cpu + 0.5) .. "%", x + tw - 60, yy, 46, "right")
            barra(x + 14, yy + 18, tw - 28, 6, q.cpu / 100, q.cpu > 50 and C.alerta or C.acento)
        end
        lg.setFont(F.chica); color(C.tenue)
        lg.print(T("%s programas abiertos", PR.total), x + 14, y + 150)
    else puntos(x + 14, y + 40) end

    ayudas({{"A", T"Detalle"}, {"X", T"Internet"}, {"Y", T"Tema"}, {"START", T"Energía"}, {"B", T"Salir"}})
end
function E.tablero.boton(b)
    local Tb = E.tablero
    local mov = {izq = -1, der = 1, arriba = -3, abajo = 3}
    if mov[b] then
        local n = Tb.sel + mov[b]
        if n >= 1 and n <= 6 and not (b == "izq" and Tb.sel % 3 == 1) and not (b == "der" and Tb.sel % 3 == 0) then Tb.sel = n; sonar("tic") end
    elseif b == "a" then sonar("abre"); ir(DESTINOS[Tb.sel])
    elseif b == "x" then sonar("abre"); ir("red"); E.red.probar()
    elseif b == "start" or b == "r" then sonar("abre"); ir("energia")   -- R1 por si START no llega a la app
    elseif b == "b" then love.event.quit() end
end

-- Batería
E.bateria = {}
function leerCurvas()
    -- el registro de la batería (bateria-registro, si estuvo encendido): la descarga completa más nueva.
    -- «Completa» = ya terminó (vino una carga después, o la consola se apagó) y bajó de 3,42 V; así no se toma
    -- la descarga que está en curso. Cada punto guarda los mAh que aún quedaban hasta el apagado (p.resta):
    -- con eso se estima el tiempo por voltaje (2026-11-17: a 3,46 V el medidor decía 21 % y quedaban 113 mAh).
    local p = io.popen("ls -1 " .. citar(REGISTRO) .. "registro-*.csv 2>/dev/null | tail -1")
    local archivo = p and p:read("*l")
    if p then p:close() end
    if not archivo then return nil end
    local f = io.open(archivo, "r")
    if not f then return nil end
    local bloques, actual, cargas, actualC = {}, nil, {}, nil
    local finCarga, filasDesde, mvUltima = nil, {}, nil   -- última fila cargando y las de después («desde la carga»)
    for l in f:lines() do
        local fecha, estado, pct, mv, ma = l:match("^(%d+%-%d+%-%d+ %d+:%d+:%d+),([^,]+),(%d+),(%d+),(%-?%d+)")
        if fecha then
            local y, mo, d, h, mi, s = fecha:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
            local t = os.time({year = y, month = mo, day = d, hour = h, min = mi, sec = s})
            if estado == "Charging" or estado == "Full" then finCarga, filasDesde = t, {}
            elseif finCarga then filasDesde[#filasDesde + 1] = t; mvUltima = tonumber(mv) end
            if estado == "Discharging" then
                if not actual then actual = {}; bloques[#bloques + 1] = actual end
                actual[#actual + 1] = {t = t, mv = tonumber(mv), pct = tonumber(pct), ma = math.abs(tonumber(ma))}
            else if actual then actual.cerrada = true end; actual = nil end
            if estado == "Charging" or estado == "Full" then
                if not actualC then actualC = {}; cargas[#cargas + 1] = actualC end
                actualC[#actualC + 1] = {t = t, mv = tonumber(mv), ma = math.abs(tonumber(ma))}
            else actualC = nil end
        end
    end
    f:close()
    -- «desde la carga»: rato encendida desde la última vez que estuvo cargando (las filas son de cada minuto
    -- encendida; los huecos de más de 30 min son ratos apagada)
    D.desdeCarga = nil
    if finCarga then
        local on, prev = 0, finCarga
        for _, tt in ipairs(filasDesde) do local dt = tt - prev; if dt < 1800 then on = on + dt end; prev = tt end
        D.desdeCarga = {t = finCarga, on = on / 60, ultima = prev, mv = mvUltima}
    end
    local carga
    for i = #cargas, 1, -1 do
        local b, e = cargas[i], nil
        for k = 1, #b do if b[k].mv >= 4140 and b[k].ma < 200 then e = k; break end end
        if e and e >= 20 and b[1].mv <= 3800 then
            local pts = {}
            for k = 1, e do pts[k] = b[k] end
            for k = 1, e do
                local sm, sa, n = 0, 0, 0
                for j = math.max(1, k - 2), math.min(e, k + 2) do sm = sm + pts[j].mv; sa = sa + pts[j].ma; n = n + 1 end
                pts[k].suave, pts[k].corr = sm / n, sa / n
            end
            pts[e].falta, pts[e].min = 0, 0
            for k = e - 1, 1, -1 do
                local dt = pts[k + 1].t - pts[k].t
                pts[k].falta = pts[k + 1].falta + (dt < 1800 and pts[k].ma * dt / 3600 or 0)
                pts[k].min = pts[k + 1].min + (dt < 1800 and dt / 60 or 0)
            end
            carga = {puntos = pts, desde = fechaCorta(pts[1].t)}
            break
        end
    end
    for i = #bloques, 1, -1 do
        local b = bloques[i]
        local terminada = b.cerrada or (#b > 0 and os.time() - b[#b].t > 15 * 60)
        -- solo una descarga que acabó con la consola apagándose sola (< 3,42 V): si se conectó el cargador antes
        -- (p. ej. a 3,53 V), haría creer que la batería se acaba a ese voltaje
        if #b >= 20 and terminada and b[#b].mv < 3420 then
            b[#b].resta = 0
            for k = #b - 1, 1, -1 do
                local dt = b[k + 1].t - b[k].t
                b[k].resta = b[k + 1].resta + (dt < 1800 and b[k].ma * dt / 3600 or 0)
            end
            for k = 1, #b do   -- voltaje suavizado (5 puntos): el de un minuto suelto salta con la carga
                local s, n = 0, 0
                for j = math.max(1, k - 2), math.min(#b, k + 2) do s = s + b[j].mv; n = n + 1 end
                b[k].suave = s / n
            end
            local min, bajo35 = 0, nil
            for k = 2, #b do
                local dt = b[k].t - b[k - 1].t
                if dt < 30 * 60 then min = min + dt / 60 end      -- los ratos apagada no cuentan
                if not bajo35 and b[k].mv < 3500 then bajo35 = k end
            end
            local extra = 0
            if bajo35 then for k = bajo35 + 1, #b do local dt = b[k].t - b[k - 1].t; if dt < 1800 then extra = extra + dt / 60 end end end
            return {puntos = b, minutos = min, extra = extra, desde = fechaCorta(b[1].t), fin = b[#b].mv,
                    inicio = b[1].mv, termino = fechaCorta(b[#b].t)}, carga
        end
    end
    return nil, carga
end
function E.bateria.entrar() E.bateria.descarga = curva end
function E.bateria.dibujar()
    cabecera(T"batería")
    panel(16, 64, 300, 200, T"AHORA")
    pilaBateria(32, 96, 2)
    lg.setFont(F.grande); color(C.crema); lg.print(D.pct .. "%", 196, 106)
    if D.pct ~= D.pctMedidor then lg.setFont(F.chica); color(C.tenue); lg.print(recortar(F.chica, T("sistema: %s%%", D.pctMedidor), 112), 196, 146) end
    lg.setFont(F.chica); color(C.tenue)
    local est = ({Charging = T"cargando", Discharging = T"descargando", Full = T"llena", ["Not charging"] = T"conectada, sin cargar"})[D.estado] or D.estado
    lg.print(coma(string.format("%.3f V · %d mA · %s", D.mv / 1000, math.floor(math.abs(D.ma) + 0.5), est)), 32, 172)
    lg.setFont(F.normal); color(C.oro)
    local que, min, por = estimar()
    if que == "quedan" and min < 5 then lg.print(T"menos de 5 min: conéctala", 32, 196)
    else lg.print(que and textoQue(que, min) or T"calculando…", 32, 196) end
    lg.setFont(F.chica); color(C.tenue)
    lg.print(por == "voltaje" and T"por voltaje, según tu última descarga" or por == "carga" and T"según tu última carga completa" or T("con %s mAh y el consumo actual", math.floor(CAPACIDAD + 0.5)), 32, 220)
    local fin = curva and curva.fin
    lg.print((fin and coma(string.format(T"la última vez se apagó en %.2f V · ", fin / 1000)) or "")
        .. T("brillo %s", D.brillo and (math.floor(D.brillo * 100 + 0.5) .. "%") or "—"), 32, 238)

    panel(332, 64, 292, 200, T"VOLTAJE · últimos 3 min")
    grafica(348, 96, 260, 150, hist.volt, 3300, 4250, C.acento, 180)
    lg.setFont(F.chica); color(C.tenue)
    lg.print(T"4,2 V", 352, 92); lg.print(T"3,4 V", 352, 228)

    -- TIEMPOS: esta sesión, desde la carga y la última descarga completa
    panel(16, 272, 608, 92, T"TIEMPOS")
    if D.registroServicio == "no" or D.registroServicio == "sinpermiso" then
        local txt = T"sin registro de batería"
        lg.setFont(F.chica); color(C.tenue); lg.print(txt, 608 - F.chica:getWidth(txt), 280)
    elseif D.registro ~= nil then
        local txt = D.registro and T"registrando cada minuto" or T"registro apagado"
        local tx = 608 - F.chica:getWidth(txt)
        lg.setFont(F.chica); color(D.registro and C.acento or C.borde); lg.circle("fill", tx - 10, 288, D.registro and 4 or 3)
        color(D.registro and C.crema or C.tenue); lg.print(txt, tx, 280)
    end
    if E.bateria.trabajando then puntos(400, 286) end
    local ti, d = tiempos(), E.bateria.descarga
    local col = {
        {T"ESTA SESIÓN", duracion(ti.sesion or 0), T("encendida desde %s", os.date("%H:%M", ti.arranque)), ""},
        ti.cargando and {T"DESDE LA CARGA", T"cargando", T"se cuenta al desconectarla", ""}
            or (ti.on and {T"DESDE LA CARGA", duracion(ti.on), T"encendida",
                T("(%s reales, desde %s)", duracion(ti.real), os.date((ti.real or 0) > 1200 and "%d/%m %H:%M" or "%H:%M", ti.desde))})
            or {T"DESDE LA CARGA", "—", D.registro and T"desde la próxima carga" or T"sin registro", ""},
        d and {T"ÚLTIMA COMPLETA", duracion(d.minutos), coma(string.format(T"de %.2f a %.2f V", d.inicio / 1000, d.fin / 1000)), T("terminó %s", d.termino)}
            or {T"ÚLTIMA COMPLETA", "—", D.registro and T"cuando se apague sola" or T"sin registro", ""},
    }
    for i, c in ipairs(col) do
        local cx = 32 + (i - 1) * 200
        lg.setFont(F.chica); color(C.tenue); lg.print(c[1], cx, 300)
        lg.setFont(F.normal); color(i == 2 and C.oro or C.crema); lg.print(c[2], cx, 316)
        lg.setFont(F.chica); color(C.tenue); lg.print(recortar(F.chica, c[3], 190), cx, 334); lg.print(recortar(F.chica, c[4], 190), cx, 348)
    end

    panel(16, 370, 608, 72, T"ÚLTIMA DESCARGA COMPLETA")
    if d then
        local x0, y0, w0, h0 = 76, 398, 532, 38     -- a la izquierda, la columna de 4,2 V y 3,4 V
        -- eje x = tiempo encendida (los ratos apagada no ocupan lugar)
        -- eje x = tiempo encendida: una pausa (más de 2 min sin filas: apagada o suspendida) no ocupa lugar. Las de más
        -- de 5 min se marcan con una raya punteada y su duración arriba (las de más de 1 h, más marcadas); las que
        -- quedan a menos de 8 px se juntan en una.
        if not d.on then
            d.on, d.cortes = {0}, {}
            for k = 2, #d.puntos do
                local dt = d.puntos[k].t - d.puntos[k - 1].t
                if dt > 120 then d.on[k] = d.on[k - 1]; if dt > 300 then d.cortes[#d.cortes + 1] = {k = k, dur = dt} end
                else d.on[k] = d.on[k - 1] + dt end
            end
        end
        local total = math.max(1, d.on[#d.on])
        local function xv(k) return x0 + d.on[k] / total * w0 end
        local function yv(mv) return y0 + h0 - limitar((mv - 3300) / 950, 0, 1) * h0 end
        -- referencias: llena (4,2 V) y vacía (3,4 V)
        color(C.borde); for xx = x0, x0 + w0, 6 do px(xx, yv(4200), 3, 1) end
        color(C.alerta, 0.5); for xx = x0, x0 + w0, 6 do px(xx, yv(3400), 3, 1) end
        local i = 1
        lg.setFont(F.chica)
        -- las duraciones van en la fila del título, a su derecha, sin pisarse entre sí
        local libreDesde = 32 + F.chica:getWidth(T"ÚLTIMA DESCARGA COMPLETA") + 16
        while i <= #d.cortes do
            local c, dur = d.cortes[i], d.cortes[i].dur
            while d.cortes[i + 1] and xv(d.cortes[i + 1].k) - xv(c.k) < 8 do i = i + 1; dur = dur + d.cortes[i].dur end
            local xc, larga = math.floor(xv(c.k)), dur >= 3600
            color(larga and C.crema or C.tenue, larga and 0.9 or 0.6)
            for yy = y0 - 6, y0 + h0, 4 do px(xc, yy, larga and 2 or 1, 2) end
            local m = math.floor(dur / 60 + 0.5)
            local et = m >= 60 and (math.floor(m / 60) .. " h" .. (m % 60 > 0 and string.format(" %02d", m % 60) or "")) or (m .. " min")
            local w = F.chica:getWidth(et)
            if xc + 4 >= libreDesde and xc + 4 + w <= x0 + w0 then
                color(larga and C.crema or C.tenue, 0.9); lg.print(et, xc + 4, 378); libreDesde = xc + 4 + w + 6
            end
            i = i + 1
        end
        for k, p in ipairs(d.puntos) do
            color(p.mv < 3500 and C.oro or C.acento); px(math.floor(xv(k) / 2) * 2, math.floor(yv(p.mv) / 2) * 2, 2, 2)
        end
        lg.setFont(F.chica); color(C.tenue); lg.print(T"4,2 V", 32, yv(4200) - 6)
        color(C.alerta, 0.8); lg.print(T"3,4 V", 32, yv(3400) - 8)
    else
        lg.setFont(F.chica); color(C.tenue)
        lg.printf(D.registroServicio == "no"
            and T"Sin registro, el porcentaje es el del sistema y puede no ser fiable. A instala el registro de batería."
            or D.registroServicio == "sinpermiso" and T"Sin registro, el porcentaje es el del sistema y puede no ser fiable."
            or T"Sin descargas completas en el registro: aparece cuando la consola se apague sola por batería baja.", 32, 392, 576)
    end
    if D.registroServicio == "pulso36" then
        ayudas({{"A", D.registro and T"Apagar registro" or T"Encender registro"}, {"X", T"Desinstalar"}, {"B", T"Volver"}})
    elseif D.registroServicio == "no" then ayudas({{"A", T"Instalar registro"}, {"B", T"Volver"}})
    else ayudas({{"B", T"Volver"}}) end
end
function E.bateria.boton(b)
    local Bt = E.bateria
    local function orden(o)
        Bt.trabajando = true
        correr(ACCIONES .. " registro " .. o, function(cod, l)
            Bt.trabajando = false
            preguntarAyudante()
            if cod == 0 then sonar("listo"); avisar(T(l[#l] or "Listo."), C.acento, 4) else sonar("error"); avisar(T(l[#l] or "No se pudo."), C.alerta, 5) end
        end)
    end
    if Bt.trabajando then return end
    if b == "a" and D.registroServicio == "no" then
        preguntar(T"¿Instalar el registro de batería?", T("Anota cada minuto el voltaje, el consumo y qué juego está abierto, en %s. Funciona también con Pulso 36 cerrado. Se quita con X.",
            (REGISTRO:gsub("/$", ""))), function()
            orden("instalar " .. citar(REGISTRO:gsub("/$", "")))
        end)
    elseif b == "x" and D.registroServicio == "pulso36" then
        preguntar(T"¿Desinstalar el registro?", T("Se borra su servicio. Lo ya anotado se queda en %s.", (REGISTRO:gsub("/$", ""))), function() orden("desinstalar") end)
    elseif b == "a" and D.registroServicio == "pulso36" and D.registro ~= nil then
        local function hacer()
            Bt.trabajando = true
            correr(ACCIONES .. " registro " .. (D.registro and "off" or "on"), function(cod, l)
                Bt.trabajando = false
                preguntarAyudante()
                if cod == 0 then sonar("listo"); avisar(T(l[#l] or "Listo."), C.acento) else sonar("error"); avisar(T(l[#l] or "No se pudo."), C.alerta) end
            end)
        end
        if D.registro then
            preguntar(T"¿Apagar el registro de batería?", T("Deja de anotar cada minuto. Lo ya registrado se queda en %s.", (REGISTRO:gsub("/$", ""))), hacer)
        else hacer() end
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Procesador
E.procesador = {sel = nil}
local MODOS = {{T"Ahorro", "powersave", T"gasta menos batería"}, {T"Normal", "interactive", T"sube cuando hace falta"},
               {T"Máximo", "performance", T"siempre a tope"}}
function E.procesador.entrar()
    local P = E.procesador
    P.sel = 2
    for i, m in ipairs(MODOS) do if m[2] == D.modo then P.sel = i end end
end
function E.procesador.dibujar()
    local P = E.procesador
    cabecera(T"procesador")
    panel(16, 64, 608, 248, T"NÚCLEOS · últimos 90 s")
    lg.setFont(F.chica); color(C.acento, 0.55); px(436, 76, 10, 8); color(C.tenue); lg.print(T"uso", 450, 72)
    color(C.crema); px(486, 79, 10, 2); color(C.tenue); lg.print("MHz", 500, 72)
    for i, n in ipairs(D.nucleos) do
        local x = 30 + (i - 1) * 148
        lg.setFont(F.normal); color(C.crema); lg.print(T("Núcleo %s", i), x, 90)
        lg.setFont(F.grande); color(n.activo and C.acento or C.borde); lg.print(n.activo and math.floor(n.mhz) or "—", x, 108)
        lg.setFont(F.chica); color(C.tenue)
        lg.print(n.activo and T("MHz · uso %s%%", math.floor(n.uso * 100 + 0.5)) or T"apagado", x, 144)
        color(C.trama); px(x, 170, 132, 120)
        grafica(x, 172, 132, 116, hist.usoNucleo[i], 0, 1, mezcla(C.acento, C.alerta, n.uso), 90, 0.55)   -- relleno: uso
        grafica(x, 172, 132, 116, suavizar(hist.nucleo[i], 5), 0, D.maxf + 60, C.crema, 90, 0)            -- línea: MHz (promedio de 5 s)
    end
    panel(16, 322, 296, 120, T"TEMPERATURA · PROCESADOR")
    lg.setFont(F.grande); color(D.temp and D.temp > 65 and C.alerta or C.oro)
    lg.print(D.temp and coma(string.format("%.1f °C", D.temp)) or "—", 30, 342)
    grafica(170, 344, 126, 34, hist.temp, 40, 80, C.oro)   -- bajita: debajo va la línea de «gráficos …»
    lg.setFont(F.chica); color(C.tenue)
    lg.print(T("gráficos %s · %s", D.gpu and (math.floor(D.gpu + 0.5) .. " MHz") or "—", D.gtemp and coma(string.format("%.1f °C", D.gtemp)) or "— °C"), 30, 384)
    lg.print(T("memoria %s MHz", math.floor(D.dmc + 0.5)), 30, 402)
    panel(328, 322, 296, 120, T"MODO DEL PROCESADOR")
    for i, m in ipairs(MODOS) do
        local yy = 348 + (i - 1) * 28
        local actual = m[2] == D.modo
        if i == P.sel then color(C.marca); lg.rectangle("fill", 340, yy - 4, 272, 24, 4, 4) end
        color(actual and C.acento or C.borde); lg.circle("fill", 354, yy + 8, actual and 6 or 4)
        lg.setFont(F.normal); color(i == P.sel and C.crema or C.tenue); lg.print(m[1], 368, yy)
        lg.setFont(F.chica); color(C.tenue); lg.print(m[3], 446, yy + 1)
    end
    if P.trabajando then puntos(590, 330) end
    ayudas({{"A", T"Usar este modo"}, {"B", T"Volver"}})
end
function E.procesador.boton(b)
    local P = E.procesador
    if b == "arriba" or b == "abajo" then
        P.sel = limitar(P.sel + (b == "arriba" and -1 or 1), 1, #MODOS); sonar("tic")
    elseif b == "a" and not P.trabajando then
        local m = MODOS[P.sel]
        if m[2] == D.modo then avisar(T("Ya está en modo %s.", m[1]:lower()), C.tenue) return end
        P.trabajando = true
        correr(ACCIONES .. " modo " .. m[2], function(cod, l)
            P.trabajando = false
            if cod == 0 then
                sonar("listo"); avisar(T("Modo %s. Pulso 36 lo recordará al abrirse.", m[1]:lower()), C.acento, 4)
                pcall(love.filesystem.write, "modo.txt", m[2])
            else sonar("error"); avisar(T(l[#l] or "No se pudo cambiar el modo."), C.alerta) end
        end)
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Memoria y ZRam
E.memoria = {}
local TAMANOS = {256, 512, 768}
function E.memoria.dibujar()
    local M = E.memoria
    local z = D.zram
    cabecera(T"memoria")
    panel(16, 64, 608, 120, "RAM")
    local usada = D.ramTotal - D.ramLibre
    local frU = usada / math.max(1, D.ramTotal)
    local pctU = math.floor(frU * 100 + 0.5) .. " %"
    lg.setFont(F.grande); color(nivel(frU) == C.acento and C.crema or nivel(frU)); lg.print(pctU, 32, 88)
    lg.setFont(F.normal); color(C.tenue); lg.print(T"en uso", 40 + F.grande:getWidth(pctU), 102)
    lg.setFont(F.chica); color(C.tenue)
    lg.print(string.format(T"%d MB usados · %d libres · %d total", usada + 0.5, D.ramLibre + 0.5, D.ramTotal + 0.5), 32, 124)
    barra(32, 148, 576, 16, usada / math.max(1, D.ramTotal), nivel(usada / math.max(1, D.ramTotal)))

    panel(16, 196, 608, 246, T"ZRAM · memoria comprimida")
    if z.servicio == "pulso36" and (z.choque or z.gestor) then   -- la de Pulso y la del sistema usan el mismo /dev/zram0
        lg.setFont(F.chica); color(z.choque and C.alerta or C.tenue)
        lg.printf(z.choque and T("Ojo: también está la de «%s». Usa solo una.", z.gestor or "zram-swap")
            or T("No actives también «%s»: usan la misma memoria.", z.gestor), 32, 204, 576, "right")
    end
    if z.activa then
        local gana = z.guardado - z.ocupa
        lg.setFont(F.grande); color(C.acento); lg.print("+" .. math.floor(gana + 0.5) .. " MB", 32, 222)
        lg.setFont(F.chica); color(C.tenue); lg.print(T"de memoria ganada ahora", 34 + F.grande:getWidth("+" .. math.floor(gana + 0.5) .. " MB") + 8, 236)
        -- dos barras: lo guardado y lo que de verdad ocupa
        local escala = 576 / math.max(1, z.tam)
        lg.setFont(F.chica); color(C.crema); lg.print(string.format(T"Guardado: %d MB", z.guardado + 0.5), 32, 270)
        color(C.trama); px(32, 290, 576, 14)
        for i = 0, z.guardado * escala - 3, 4 do color(C.oro, 0.85); px(33 + i, 291, 3, 12) end
        color(C.crema); lg.print(string.format(T"Ocupa en la RAM: %d MB", z.ocupa + 0.5), 32, 312)
        color(C.trama); px(32, 332, 576, 14)
        for i = 0, z.ocupa * escala - 3, 4 do color(C.acento, 0.85); px(33 + i, 333, 3, 12) end
        local ratio = z.ocupa > 0 and z.guardado / z.ocupa or 0
        color(C.tenue)
        lg.print(z.ocupa >= 1 and coma(string.format(T"Comprime %.1f a 1 · tamaño %d MB", ratio, z.tam + 0.5)) or string.format(T"Encendida y esperando: todavía no hizo falta · tamaño %d MB", z.tam + 0.5), 32, 356)
    else
        local s = z.servicio
        lg.setFont(F.grande); color(C.tenue)
        lg.print(s == "pulso36" and T"Apagada" or s == "sistema" and T"Apagada" or s == "no" and T"No instalada" or T"Sin ZRam", 32, 222)
        lg.setFont(F.chica)
        lg.printf(T"Guarda en la RAM, comprimido, lo que no cabe: los juegos pesados no se cierran de golpe por falta de memoria.", 32, 266, 570)
        color(C.oro)
        if s == "no" then
            lg.printf(T"A para instalarla: Pulso 36 deja un servicio que la enciende al arrancar (se quita con X).", 32, 310, 570)
        elseif s == "nada" then lg.printf(D.sudo == false and T"Esta consola no deja instalarla (falta sudo sin contraseña)." or T"Este sistema no trae zram.", 32, 310, 570)
        else   -- apagada (la nuestra o la del sistema): ¿hace falta con la RAM que queda libre?
            local libre = math.floor(D.ramLibre + 0.5)
            color(libre >= 500 and C.tenue or C.oro)
            lg.printf(libre >= 500 and T("Con %s MB libres ahora no hace falta. Conviene encenderla para PSP, N64 o Dreamcast, o si un juego se cierra solo.", libre)
                or T("Quedan %s MB libres: conviene encenderla para que los juegos pesados no se cierren.", libre), 32, 310, 570)
        end
    end
    lg.setFont(F.chica); color(C.tenue)
    if z.servicio == "pulso36" then
        lg.print(T("Al arrancar: %s", z.arranque and T"sí" or T"no"), 32, 382)
        lg.print(T"Tamaño elegido:", 220, 382)
        for i, t in ipairs(TAMANOS) do
            local x = 336 + (i - 1) * 74
            local el = (z.elegido or 512) == t
            if el then color(C.marca); lg.rectangle("fill", x - 6, 378, 66, 24, 4, 4) end
            lg.setFont(el and F.normal or F.chica); color(el and C.crema or C.tenue); lg.print(t .. " MB", x, 382)
        end
    elseif z.servicio == "sistema" then
        local pie
        if z.gestor and z.confMb then
            pie = T("Configurada en «%s»: %s MB%s · al arrancar: %s. Se cambia desde ahí, en las opciones del menú.",
                z.gestor, z.confMb, z.confAlgo and (" · " .. z.confAlgo) or "", z.sisArranque and T"sí" or T"no")
        elseif z.gestor then
            pie = T("La enciende «%s», en las opciones del menú. Todavía no está configurada.", z.gestor)
        else pie = T"La ZRam la maneja el sistema: se cambia desde sus herramientas, no desde Pulso 36." end
        lg.printf(pie, 32, 376, 576)
    end
    if M.trabajando then puntos(590, 214) end
    if z.servicio == "pulso36" then
        ayudas({{"A", z.activa and T"Apagar" or T"Encender"}, {"L/R", T"Tamaño"}, {"X", T"Desinstalar"}, {"B", T"Volver"}})
    elseif z.servicio == "no" then ayudas({{"A", T"Instalar"}, {"B", T"Volver"}})
    else ayudas({{"B", T"Volver"}}) end
end
function E.memoria.boton(b)
    local M = E.memoria
    local z = D.zram
    if M.trabajando then return end
    local function hecho(cod, l, msg)
        M.trabajando = false
        preguntarAyudante()
        if cod == 0 then sonar("listo"); avisar(T(msg or l[#l] or "Listo."), C.acento) else sonar("error"); avisar(T(l[#l] or "No se pudo."), C.alerta) end
    end
    local s = z.servicio
    if b == "a" and s == "no" then
        preguntar(T"¿Instalar ZRam?", T"Pulso 36 instala un servicio pequeño (pulso36-zram) que la enciende con 512 MB en cada arranque. Se quita con X.", function()
            M.trabajando = true
            correr(ACCIONES .. " zram instalar", function(c, l) hecho(c, l) end)
        end)
    elseif b == "x" and s == "pulso36" then
        preguntar(T"¿Desinstalar la ZRam de Pulso 36?", T"Se apaga y se borra su servicio: el sistema queda como antes de instalarla.", function()
            M.trabajando = true
            correr(ACCIONES .. " zram desinstalar", function(c, l) hecho(c, l) end)
        end)
    elseif s ~= "pulso36" then
        if b == "b" then sonar("cierra"); ir("tablero") end
    elseif b == "a" then
        if z.activa then
            preguntar(T"¿Apagar ZRam?", T"Lo que está guardado ahí vuelve a la RAM. Tampoco se encenderá al arrancar.", function()
                M.trabajando = true
                correr(ACCIONES .. " zram off", function(c, l) hecho(c, l, T"ZRam apagada.") end)
            end)
        else
            local function encender()
                M.trabajando = true
                correr(ACCIONES .. " zram on", function(c, l) hecho(c, l, T"ZRam encendida, también al arrancar.") end)
            end
            if z.choque then
                preguntar(T"¿Encender la ZRam de Pulso 36?", T("También está configurada la de «%s». Las dos usan la misma memoria: al arrancar, una falla o apaga a la otra. Mejor desactiva una de las dos.",
                    z.gestor or "zram-swap"), encender)
            else encender() end
        end
    elseif b == "l" or b == "r" or b == "izq" or b == "der" then
        local i = 2
        for k, t in ipairs(TAMANOS) do if t == (z.elegido or 512) then i = k end end
        local n = limitar(i + ((b == "l" or b == "izq") and -1 or 1), 1, #TAMANOS)
        if n == i then return end
        z.elegido = TAMANOS[n]
        M.trabajando = true
        correr(ACCIONES .. " zram tam " .. TAMANOS[n], function(c, l) hecho(c, l, "ZRam: " .. TAMANOS[n] .. " MB.") end)
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Energía
E.energia = {sel = 1}
local OPCIONES_ENERGIA = {
    {T"Apagar al terminar de cargar", "vigilar"},
    {T"Reiniciar el menú", "menu", {T"¿Reiniciar el menú?", T"Se cierra Pulso 36 y EmulationStation vuelve a arrancar. Sirve si el menú quedó raro o lento."}},
    {T"Reiniciar la consola", "reiniciar", {T"¿Reiniciar la consola?", T"Se cierra todo. Guarda la partida si tienes un juego abierto."}},
    {T"Apagar la consola", "apagar", {T"¿Apagar la consola?", T"Se cierra todo. Guarda la partida si tienes un juego abierto."}},
}
function E.energia.dibujar()
    local En = E.energia
    cabecera(T"energía")
    panel(16, 64, 608, 120, T"BATERÍA AHORA")
    pilaBateria(32, 96, 1)
    lg.setFont(F.grande); color(C.crema); lg.print(D.pct .. "%", 110, 94)
    lg.setFont(F.chica); color(C.tenue)
    local est = ({Charging = T"cargando", Discharging = T"descargando", Full = T"llena", ["Not charging"] = T"conectada, sin cargar"})[D.estado] or D.estado
    lg.print(coma(string.format("%.3f V · %d mA · %s", D.mv / 1000, math.floor(math.abs(D.ma) + 0.5), est)), 32, 140)
    lg.print(T"Llena de verdad: más de 4,14 V y menos de 200 mA. El sistema marca 100 % antes.", 32, 158)
    local cerca = D.cargador and D.mv >= 4150 and D.ma < 200
    lg.setFont(F.normal); color(cerca and C.acento or C.oro)
    lg.printf(D.cargador and (cerca and T"casi llena" or T"cargando") or T"sin cargador", 300, 100, 308, "right")

    panel(16, 194, 608, 248, T"ENERGÍA", true)
    for i, o in ipairs(OPCIONES_ENERGIA) do
        local yy = 228 + (i - 1) * 46
        local el = En.sel == i
        if el then color(C.marca); lg.rectangle("fill", 28, yy - 8, 584, 38, 5, 5); color(C.acento); px(36, yy + 6, 5, 5) end
        lg.setFont(F.normal); color(el and C.crema or C.tenue); lg.print(o[1], 52, yy)
        lg.setFont(F.chica); color(C.tenue)
        if i == 1 then
            if D.vigila then color(C.oro, 0.7 + 0.3 * math.sin(reloj * 3)); lg.printf(T"ACTIVO: vigilando la carga", 300, yy, 300, "right")
            else lg.printf(D.cargador and T"conectada: se puede activar" or T"conecta el cargador", 300, yy, 300, "right") end
            color(C.tenue); lg.print(T"Ideal para dejarla cargando de noche. Si la desconectas, no se apaga.", 52, yy + 16)
        elseif i == 2 then lg.print(T"Cierra Pulso 36 y vuelve a abrir EmulationStation", 52, yy + 16)
        elseif i == 3 then lg.print(T"Apaga y vuelve a encender", 52, yy + 16)
        else lg.print(T"Apaga ahora", 52, yy + 16) end
    end
    if En.trabajando then puntos(590, 202) end
    ayudas({{"A", (En.sel == 1 and D.vigila) and T"Cancelar" or T"Elegir"}, {"B", T"Volver"}})
end
function E.energia.boton(b)
    local En = E.energia
    if b == "arriba" or b == "abajo" then En.sel = limitar(En.sel + (b == "arriba" and -1 or 1), 1, #OPCIONES_ENERGIA); sonar("tic")
    elseif b == "a" and not En.trabajando then
        local o = OPCIONES_ENERGIA[En.sel]
        local orden = o[2]
        if orden == "vigilar" and D.vigila then orden = "cancelar" end
        local function hacer()
            En.trabajando = true
            correr(ACCIONES .. " energia " .. orden, function(cod, l)
                En.trabajando = false
                preguntarAyudante()
                if cod == 0 then sonar("listo"); avisar(T(l[#l] or "Listo."), C.acento, 4) else sonar("error"); avisar(T(l[#l] or "No se pudo."), C.alerta, 4) end
            end)
        end
        if o[3] then preguntar(o[3][1], o[3][2], hacer) else hacer() end
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Procesos
E.procesos = {sel = 1}
function E.procesos.entrar() E.procesos.sel, E.procesos.selPid = 1, nil; leerProcesos() end
function E.procesos.dibujar()
    local P = E.procesos
    cabecera(T"procesos")
    panel(16, 64, 608, 378, T"LOS QUE MÁS CONSUMEN AHORA")
    lg.setFont(F.chica); color(C.tenue)
    lg.print(T"procesador", 380, 72); lg.printf(T"memoria", 500, 72, 106, "right")
    local l = PR.lista
    if not l then puntos(32, 110) else
        if P.selPid then for k, q in ipairs(l) do if q.pid == P.selPid and k <= 12 then P.sel = k end end end
        P.sel = limitar(P.sel, 1, math.min(12, #l))
        P.selPid = l[P.sel] and l[P.sel].pid
        for k = 1, math.min(12, #l) do
            local q = l[k]
            local yy = 96 + (k - 1) * 27
            local el = k == P.sel
            if el then color(C.marca); lg.rectangle("fill", 24, yy - 4, 592, 24, 4, 4); color(C.acento); px(30, yy + 6, 4, 4) end
            lg.setFont(el and F.normal or F.chica); color(q.protegido and (el and C.tenue or C.borde) or (el and C.crema or C.tenue))
            if q.protegido and not el then color(C.tenue, 0.7) end
            lg.print(recortar(el and F.normal or F.chica, q.nombre or q.comm, 290), 42, yy)
            barra(380, yy + 5, 70, 8, q.cpu / 100, q.cpu > 50 and C.alerta or C.acento)
            lg.setFont(F.chica); color(q.cpu > 50 and C.alerta or C.oro)
            lg.printf(coma(string.format(q.cpu < 10 and "%.1f%%" or "%d%%", q.cpu)), 452, yy, 50, "right")
            color(C.tenue); lg.printf(math.floor(q.ram + 0.5) .. " MB", 510, yy, 96, "right")
        end
        local q = l[P.sel]
        lg.setFont(F.chica); color(C.tenue)
        lg.print(q and (q.protegido and T"Es parte del sistema: no se cierra desde aquí." or T"A para cerrarlo si se quedó trabado.") or "", 32, 418)
        lg.printf(T("%s programas", PR.total), 32, 418, 576, "right")
    end
    if P.trabajando then puntos(590, 72) end
    ayudas({{"A", T"Cerrar"}, {"B", T"Volver"}})
end
function E.procesos.boton(b)
    local P = E.procesos
    local l = PR.lista
    if b == "arriba" or b == "abajo" then
        if l then P.sel = limitar(P.sel + (b == "arriba" and -1 or 1), 1, math.min(12, #l)); P.selPid = l[P.sel].pid; sonar("tic") end
    elseif b == "a" and l and l[P.sel] and not P.trabajando then
        local q = l[P.sel]
        if q.protegido then sonar("error"); avisar(T"Es parte del sistema: mejor no cerrarlo.", C.alerta) return end
        preguntar(T("¿Cerrar %s?", q.nombre or q.comm), T"Si es un juego, se pierde lo que no hayas guardado.", function()
            P.trabajando = true
            correr(ACCIONES .. " cerrar " .. q.pid .. " " .. citar(q.comm or ""), function(cod, r)
                P.trabajando = false
                leerProcesos()
                if cod == 0 then sonar("listo"); avisar(T(r[#r] or "Cerrado."), C.acento) else sonar("error"); avisar(T(r[#r] or "No se pudo cerrar."), C.alerta) end
            end)
        end)
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Almacenamiento: espacio libre y qué ocupa la SD (du tarda ~20 s: se calcula a pedido y se guarda)
E.almacenamiento = {}
local CARPETAS = {ports = "Ports", psx = "PlayStation", dreamcast = "Dreamcast", gba = "Game Boy Advance", mame2003 = "MAME 2003",
    neogeo = "Neo Geo", pcenginecd = "PC Engine CD", n64 = "Nintendo 64", megadrive = "Mega Drive", snes = "Super Nintendo",
    tools = T"Herramientas", bios = "BIOS", cps1 = "CPS1", cps2 = "CPS2", cps3 = "CPS3", msx = "MSX", msx2 = "MSX2", psp = "PSP",
    gbc = "Game Boy Color", gb = "Game Boy", nes = "NES", themes = T"Temas", famicom = "Famicom", nds = "Nintendo DS",
    genesis = "Genesis", segacd = "Sega CD", saturn = "Saturn", backup = T"Respaldos",
    videos = T"Videos", movies = T"Películas", bgmusic = T"Música de fondo", launchimages = T"Pantallas de carga",
    mastersystem = "Master System", gamegear = "Game Gear", pcengine = "PC Engine", arcade = "Arcade", fbneo = "FinalBurn Neo",
    mame = "MAME", atari2600 = "Atari 2600", scummvm = "ScummVM", dos = "DOS",
    sfc = "Super Famicom", ["pico-8"] = "PICO-8", openbor = "OpenBOR", ngpc = "Neo Geo Pocket Color"}
local function cargarOcupa()
    local t = love.filesystem.read("ocupa.txt")
    if not t then return nil end
    local o = {fecha = t:match("^FECHA=(.-)\n"), epoca = tonumber(t:match("\nEPOCA=(%d+)")), lista = {}}
    if not o.epoca and o.fecha then   -- archivos de antes: «dd/mm HH:MM» de este año (o del pasado si queda en el futuro)
        local d, m, hh, mm = o.fecha:match("^(%d+)/(%d+) (%d+):(%d+)")
        if d then
            local hoy = os.date("*t")
            o.epoca = os.time({year = hoy.year, month = tonumber(m), day = tonumber(d), hour = tonumber(hh), min = tonumber(mm)})
            if o.epoca > os.time() then o.epoca = os.time({year = hoy.year - 1, month = tonumber(m), day = tonumber(d), hour = tonumber(hh), min = tonumber(mm)}) end
        end
    end
    for linea in t:gmatch("[^\n]+") do
        local kb, ruta = linea:match("^(%d+)%s+(/%S.*)$")
        if not kb then goto siguiente end
        local c = ruta:match("([^/]+)/?$")
        if c and c ~= "System Volume Information" then o.lista[#o.lista + 1] = {nombre = CARPETAS[c] or c, gb = tonumber(kb) / 1048576} end
        ::siguiente::
    end
    table.sort(o.lista, function(a, b) return a.gb > b.gb end)
    return o
end
function E.almacenamiento.entrar() E.almacenamiento.ocupa = E.almacenamiento.ocupa or cargarOcupa() end
function E.almacenamiento.dibujar()
    local A = E.almacenamiento
    cabecera(T"almacenamiento")
    panel(16, 64, 608, 142, T"ESPACIO LIBRE")
    local lista = {{ROMS, T"Juegos (SD)"}, {"/", T"Sistema"}, {"/boot", T"Arranque"}}
    for i, l in ipairs(lista) do
        local yy = 92 + (i - 1) * 36
        lg.setFont(F.normal); color(C.crema); lg.print(l[2], 32, yy)
        local d = D.discos[l[1]]
        if d then
            local fr = d.usado / d.total
            barra(160, yy + 3, 250, 12, fr, nivel(fr))
            local libre = d.total - d.usado
            lg.setFont(F.chica); color(fr > 0.85 and C.alerta or C.tenue)
            local txt = libre >= 1 and coma(string.format("%.1f GB", libre)) or string.format("%d MB", libre * 1024 + 0.5)
            lg.printf(T("%s libres · %s %% usado", txt, math.floor(fr * 100 + 0.5)), 420, yy, 188, "right")
        else puntos(160, yy + 6) end
    end
    panel(16, 216, 608, 226, T"QUÉ OCUPA LA SD")
    local o = A.ocupa
    if A.calculando and (not o or #o.lista == 0) then
        puntos(32, 300)
        lg.setFont(F.chica); color(C.tenue); lg.print(T"Empezando a medir las carpetas de la SD…", 60, 294)
    elseif not o or #o.lista == 0 then
        lg.setFont(F.chica); color(C.tenue)
        lg.printf(T"A para medir cuánto ocupa cada sistema. Tarda unos 20 segundos y se guarda para la próxima vez.", 40, 300, 560, "center")
    else
        local mx = o.lista[1].gb
        local vis = {}   -- las de 0 MB no se listan: van a «carpetas más»
        for _, it in ipairs(o.lista) do if #vis < 14 and it.gb * 1024 >= 0.5 then vis[#vis + 1] = it end end
        for k = 1, #vis do
            local it = vis[k]
            local cx = k <= 7 and 32 or 326
            local yy = 244 + ((k - 1) % 7) * 24
            lg.setFont(F.chica); color(k <= 3 and C.crema or C.tenue)
            lg.print(recortar(F.chica, it.nombre, 128), cx, yy)
            barra(cx + 132, yy + 5, 70, 8, it.gb / mx, k <= 3 and C.oro or C.acento)
            color(k <= 3 and C.oro or C.tenue)
            lg.printf(it.gb >= 1 and coma(string.format("%.1f GB", it.gb)) or string.format("%d MB", it.gb * 1024 + 0.5), cx + 204, yy, 74, "right")
        end
        local resto, total = 0, 0
        for _, it in ipairs(o.lista) do total = total + it.gb end
        for _, it in ipairs(vis) do resto = resto - it.gb end
        resto = math.max(0, resto + total)
        local mas = #o.lista - #vis
        lg.setFont(F.chica); color(C.tenue)
        if A.calculando then
            local fr = A.total and A.hechas / math.max(1, A.total) or 0
            lg.print(T("Midiendo: %s de %s carpetas", A.hechas, A.total or "?"), 32, 418)
            barra(260, 422, 348, 10, fr, C.oro)
        else
            local viejo = o.epoca and os.time() - o.epoca > 86400
            local fecha = T("medido %s", o.epoca and fechaCorta(o.epoca) or o.fecha or "?") .. (viejo and T" (viejo · A para medir)" or "")
            color(viejo and C.oro or C.tenue); lg.print(fecha, 32, 418)
            color(C.tenue)
            if mas > 0 then lg.printf(T("%s carpetas más: %s", mas, resto * 1024 >= 0.5 and (resto >= 1 and coma(string.format("%.1f GB", resto)) or string.format("%d MB", resto * 1024 + 0.5)) or T"vacías"), 32, 418, 576, "right") end
        end
    end
    ayudas({{"A", (o and #o.lista > 0) and T"Volver a medir" or T"Medir"}, {"B", T"Volver"}})
end
function E.almacenamiento.boton(b)
    local A = E.almacenamiento
    if b == "a" and not A.calculando then
        A.calculando, A.hechas, A.total, A.medidas = true, 0, nil, {}
        A.ocupa = {fecha = T"midiendo…", lista = {}}
        correr(ACCIONES .. " ocupa", function(cod)
            A.calculando = false
            if cod == 0 and #A.medidas > 0 then
                pcall(love.filesystem.write, "ocupa.txt", "FECHA=" .. os.date("%d/%m %H:%M") .. "\nEPOCA=" .. os.time() .. "\n" .. table.concat(A.medidas, "\n") .. "\n")
                A.ocupa = cargarOcupa(); sonar("listo")
            else sonar("error"); avisar(T"No se pudo medir la SD.", C.alerta); A.ocupa = cargarOcupa() end
        end, function(l)   -- cada carpeta llega apenas se mide: la lista crece en vivo
            local t = l:match("^TOTAL=(%d+)")
            if t then A.total = tonumber(t) return end
            local kb, ruta = l:match("^(%d+)%s+(/%S.*)$")
            if not kb then return end
            A.hechas = A.hechas + 1
            A.medidas[#A.medidas + 1] = l
            local c = ruta:match("([^/]+)/?$")
            if c and c ~= "System Volume Information" then
                local lista = A.ocupa.lista
                lista[#lista + 1] = {nombre = CARPETAS[c] or c, gb = tonumber(kb) / 1048576}
                table.sort(lista, function(a, b) return a.gb > b.gb end)
            end
        end, 300)
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- Red
E.red = {pasos = nil}
local OPCIONES_RED = {
    {T"Encender SSH", "servicios ssh", {T"¿Encender SSH?",
        T"Cualquiera en esta red podrá intentar entrar con el usuario y la clave de la consola. Si nunca la cambiaste (en ArkOS es ark/ark), cámbiala antes. Se apaga al reiniciar."}},
    {T"Apagar servicios remotos", "servicios apagar", {T"¿Apagar los servicios remotos?",
        T"Apaga SSH, Samba y FileBrowser. Si estás conectado desde otro equipo, se corta la conexión."}},
    {T"Wifi solo en 2,4 GHz", "banda 24", {T"¿Fijar esta red a 2,4 GHz?",
        T"Solo la red conectada ahora. Sirve si el Wifi se corta en 5 GHz. Se deshace con «Wifi en automático»."}},
    {T"Wifi en automático", "banda auto"},
}
local NOMBRES_PASOS = {T"Router", "Internet (1.1.1.1)", T"Nombres (DNS)", T"Web segura"}
function E.red.probar()
    local R = E.red
    if R.probando then return end
    R.probando, R.pasos = true, {}
    correr(ACCIONES .. " internet", function(cod)
        R.probando = false
        local ok = 0
        for _, p in pairs(R.pasos) do if p.ok then ok = ok + 1 end end
        if ok == 4 then sonar("listo") elseif cod ~= 0 or ok < 4 then sonar("error") end
    end, function(l)
        local n, ok, det = l:match("^PASO|(%d)|(%a+)|(.*)$")
        if n then
            R.pasos[tonumber(n)] = {ok = ok == "ok", texto = det, arreglando = ok == "arreglando"}
            sonar(ok == "ok" and "tic" or ok == "arreglando" and "abre" or "error")
        end
    end)
end
function E.red.dibujar()
    local R = E.red
    cabecera(T"red")
    local r = D.red
    panel(16, 64, 300, 200, "WIFI")
    senalBarras(28, 92, 2, r.senal)
    lg.setFont(F.grande); color(C.crema); lg.print(recortar(F.grande, r.ssid or T"sin Wifi", 196), 104, 88)
    lg.setFont(F.chica); color(C.tenue)
    local canal = r.freq and (r.freq >= 5000 and math.floor((r.freq - 5000) / 5) or math.floor((r.freq - 2407) / 5))
    lg.print((r.freq and (r.freq >= 5000 and "5 GHz" or T"2,4 GHz") or "—") .. (canal and T(" · canal %s", canal) or "")
        .. (r.banda == "bg" and T" · fijada" or ""), 104, 128)
    color(C.tenue)
    lg.print(T("señal %s", r.senal and (r.senal .. " dBm (" .. calidad(r.senal) .. ")") or "—"), 104, 146)
    lg.print(T("enlace %s", r.enlace and (math.floor(r.enlace + 0.5) .. " Mbit/s") or "—"), 104, 164)
    lg.setFont(F.normal); color(C.oro); lg.print("IP  " .. (r.ip or "—"), 32, 200)
    lg.setFont(F.chica); color(C.tenue); lg.print(T"para entrar por SSH", 32, 222)
    panel(332, 64, 292, 200, T"SERVICIOS REMOTOS", R.foco == "servicios")
    local sv = D.servicios
    for i, s in ipairs({{"SSH", "ssh"}, {"Samba", "samba"}, {"FileBrowser", "fb"}}) do
        local x = 346 + (i - 1) * 86
        local on = sv and sv[s[2]]
        color(on and C.acento or C.borde); lg.circle("fill", x + 4, 98, on and 4 or 3)
        lg.setFont(F.chica); color(on and C.crema or C.tenue); lg.print(s[1], x + 12, 89)
    end
    for i, o in ipairs(OPCIONES_RED) do
        local yy = 118 + (i - 1) * 26
        local el = R.foco == "servicios" and R.sel == i
        local hecho = E.red.vigente(i)   -- ya está así: se muestra apagada y con ✓
        if el then color(C.marca); lg.rectangle("fill", 342, yy - 3, 272, 22, 4, 4); color(C.acento); px(348, yy + 6, 4, 4) end
        lg.setFont(el and F.normal or F.chica); color(el and C.crema or C.tenue, hecho and not el and 0.75 or 1)
        local txt = (i == 1 and hecho) and T"SSH encendido" or o[1]
        lg.print(txt, 360, yy)
        if hecho then sello(366 + (el and F.normal or F.chica):getWidth(txt), yy + 4, C.acento) end
    end
    if R.trabajando then puntos(590, 72) end
    panel(16, 272, 608, 92, T"TRÁFICO · últimos 90 s")
    lg.setFont(F.chica); color(C.acento); lg.print(T("baja %s", velocidad(r.baja)), 200, 280)
    color(C.oro); lg.print(T("sube %s", velocidad(r.sube)), 330, 280)
    color(C.tenue); lg.printf(T("total %s / %s", cantidad(r.totalBaja), cantidad(r.totalSube)), 32, 280, 576, "right")
    color(C.trama); px(32, 300, 576, 56)
    color(C.borde); px(32, 300 + 28, 576, 1)   -- mitad de la escala
    local tope = graficaTrafico(32, 300, 576, 56)
    lg.setFont(F.chica); color(C.tenue); lg.print(T("máx %s", velocidad(tope)), 36, 302)
    panel(16, 372, 608, 70, T"PRUEBA DE INTERNET")
    lg.setFont(F.chica); color(C.tenue); lg.printf(T"Cambiar de Wifi: Opciones > Wifi", 32, 380, 576, "right")
    if not R.pasos then
        lg.printf(T"X para probar el router, internet, los nombres (DNS) y una web segura", 32, 406, 576, "center")
    else
        for i, nombre in ipairs(NOMBRES_PASOS) do
            local cx, yy = i % 2 == 1 and 30 or 326, 398 + math.floor((i - 1) / 2) * 20
            local p = R.pasos[i]
            if p and p.arreglando then puntos(cx - 2, yy + 5, C.oro)
            elseif p then
                if p.ok then sello(cx, yy + 2, C.acento) else color(C.alerta); px(cx, yy + 2, 2, 2); px(cx + 6, yy + 2, 2, 2); px(cx + 2, yy + 4, 4, 4); px(cx, yy + 8, 2, 2); px(cx + 6, yy + 8, 2, 2) end
            elseif R.probando then puntos(cx - 2, yy + 5) end
            lg.setFont(F.chica); color(p and C.crema or C.tenue); lg.print(nombre, cx + 18, yy)
            color(p and (p.arreglando and C.oro or p.ok and C.tenue or C.alerta) or C.oro)
            lg.print(recortar(F.chica, p and T(p.texto) or (R.probando and T"comprobando" or ""), 128), cx + 154, yy)
        end
    end
    ayudas({{"A", T"Hacer"}, {"X", T"Probar internet"}, {"B", T"Volver"}})
end
function E.red.vigente(i)   -- la opción i ya está en efecto (no hace falta elegirla)
    local sv, banda = D.servicios, D.red.banda
    if i == 1 then return sv and sv.ssh or false end
    if i == 3 then return banda == "bg" end
    if i == 4 then return banda ~= nil and banda ~= "bg" end   -- sin dato (nil) no se marca
    return false
end
function E.red.entrar() E.red.foco, E.red.sel = "servicios", E.red.sel or 1 end
function E.red.boton(b)
    local R = E.red
    if b == "x" then R.probar()
    elseif b == "arriba" or b == "abajo" then R.sel = limitar(R.sel + (b == "arriba" and -1 or 1), 1, #OPCIONES_RED); sonar("tic")
    elseif b == "a" and not R.trabajando and R.vigente(R.sel) then
        sonar("tic"); avisar(R.sel == 1 and T"SSH ya está encendido." or T"Ya está así.", C.acento)
    elseif b == "a" and not R.trabajando then
        local o = OPCIONES_RED[R.sel]
        local function hacer()
            R.trabajando = true
            correr(ACCIONES .. " " .. o[2], function(cod, l)
                R.trabajando = false
                preguntarAyudante()
                if cod == 0 then sonar("listo"); avisar(T(l[#l] or "Listo."), C.acento, 4) else sonar("error"); avisar(T(l[#l] or "No se pudo."), C.alerta, 5) end
            end)
        end
        if o[3] then preguntar(o[3][1], o[3][2], hacer) else hacer() end
    elseif b == "b" then sonar("cierra"); ir("tablero") end
end

-- ── encima: pregunta y aviso ──
local function dibujarPregunta()
    if not pregunta then return end
    local e = salida(limitar((reloj - pregunta.t0) / 0.25, 0, 1))
    color(C.fondo, 0.8 * e); lg.rectangle("fill", 0, 0, W, H)
    local w, h = 460, 150
    local x, y = (W - w) / 2, (H - h) / 2 + (1 - e) * 16
    panel(x, y, w, h)
    lg.setFont(F.normal); color(C.oro); lg.printf(pregunta.titulo, x + 20, y + 18, w - 40)
    lg.setFont(F.chica); color(C.crema); lg.printf(pregunta.texto, x + 20, y + 48, w - 40)
    local bx = boton(x + 20, y + h - 30, "A", T"Sí")
    boton(bx, y + h - 30, "B", T"No")
end
local function dibujarToast()
    if not toast then return end
    local t = reloj - toast.t0
    if t > toast.dur then toast = nil return end
    local a = limitar(t * 5, 0, 1) * limitar((toast.dur - t) * 3, 0, 1)
    lg.setFont(F.chica)
    local _, l = F.chica:getWrap(toast.texto, 520)
    local h = #l * 17 + 14
    color(C.panel, 0.95 * a); lg.rectangle("fill", W / 2 - 280, H - 70 - h, 560, h, 6, 6)
    color(C.borde, a); lg.rectangle("line", W / 2 - 279.5, H - 69.5 - h, 559, h - 1, 6, 6)
    color(toast.color, a); lg.printf(toast.texto, W / 2 - 260, H - 63 - h, 520, "center")
end

-- ── aviso de batería baja ──
-- Pulso avisa él mismo con su estimación de minutos: ~30 min «baja» y ~10 min «crítica», una vez por descarga, si la
-- estimación se sostiene 30 s (abrir algo pesado no basta). Recuadro grande ~12 s y sonido: con el servicio de
-- dArkOS instalado (aviso-bateria), Pulso dice sus mismas grabaciones, porque mientras está abierto es el único que
-- puede sonar; sin él, un tono de alarma (en ArkOS el sistema ya habla). Si el servicio va a apagar la consola, deja
-- la hora en /dev/shm/aviso-bateria-apagado y Pulso muestra la cuenta regresiva. PULSO_AVISO=baja|critica|apagado
-- fuerza el recuadro (para capturas).
local RAIZ_AV = os.getenv("PULSO_RAIZ") or ""
local VOZ_AV = os.getenv("PULSO_VOZ") or (RAIZ_AV .. "/home/ark/.local/share/aviso-bateria/voz/")
local SERVICIO_AV = RAIZ_AV .. "/usr/local/bin/aviso-bateria.py"
local APAGADO_AV = RAIZ_AV .. "/dev/shm/aviso-bateria-apagado"
local AV = {dichos = {}, baja = 0, critica = 0, actual = nil, apagado = nil}
local function existe(ruta) local f = io.open(ruta, "rb"); if f then f:close() return true end return false end
local function sonarAviso(wav)
    if existe(SERVICIO_AV) then
        local f = io.open(VOZ_AV .. wav, "rb")
        if f then
            local datos = f:read("*a"); f:close()
            local ok, fuente = pcall(function()
                return love.audio.newSource(love.sound.newSoundData(love.filesystem.newFileData(datos, wav)), "static")
            end)
            if ok then fuente:play() return end
        end
    end
    if S.alarma then S.alarma:clone():play() end
end
local function lanzarAviso(tipo, titulo, texto, wav, dur)
    AV.actual = {tipo = tipo, titulo = titulo, texto = texto, t0 = reloj, dur = dur or 12}
    if wav then sonarAviso(wav) end
end
local function cinco(m) return math.max(5, math.floor(m / 5 + 0.5) * 5) end
local function revisarAviso()
    if AV.fijo then return end
    local f = io.open(APAGADO_AV, "r")
    local fin = f and tonumber(f:read("*l") or "")
    if f then f:close() end
    if fin and fin > os.time() then
        if not AV.apagado then sonarAviso("apagando.wav") end
        AV.apagado = fin
    elseif AV.apagado then
        AV.apagado = nil
        if D.cargador then
            lanzarAviso("cancelado", T"CARGADOR CONECTADO", T"La consola ya no se apagará.", nil, 5)
            sonar("listo")
        end
    end
    if D.cargador then AV.dichos, AV.baja, AV.critica = {}, 0, 0 return end
    local que, min = estimar()
    if que ~= "quedan" or not min then AV.baja, AV.critica = 0, 0 return end
    AV.critica = min <= 10 and AV.critica + 1 or 0
    AV.baja = min <= 30 and AV.baja + 1 or 0
    if AV.critica >= 30 and not AV.dichos.critica then
        AV.dichos.baja, AV.dichos.critica = true, true
        local n = min < 5 and 0 or math.min(10, cinco(min))
        lanzarAviso("critica", T"BATERÍA CRÍTICA", n > 0 and T("Quedan unos %d min. Guarda tu partida y conecta el cargador.", n)
            or T"Guarda tu partida y conecta el cargador ya.", "critica-" .. n .. ".wav")
    elseif AV.baja >= 30 and min > 10 and not AV.dichos.baja then
        AV.dichos.baja = true
        local n = math.min(30, math.max(15, cinco(min)))
        lanzarAviso("baja", T"BATERÍA BAJA", T("Quedan unos %d min. Conecta el cargador pronto.", n), "baja-" .. n .. ".wav")
    end
end
local function dibujarAviso()
    local titulo, texto, a
    if AV.apagado then
        local quedan = math.max(0, AV.apagado - os.time())
        titulo, texto, a = T"BATERÍA AGOTADA", T("La consola se apaga en %d s. Conecta el cargador para cancelarlo.", quedan), 1
    elseif AV.actual then
        local t = reloj - AV.actual.t0
        if t > AV.actual.dur then AV.actual = nil return end
        titulo, texto = AV.actual.titulo, AV.actual.texto
        a = limitar(t * 4, 0, 1) * limitar((AV.actual.dur - t) * 2, 0, 1)
    else
        return
    end
    local c = (AV.actual and AV.actual.tipo == "cancelado" and not AV.apagado) and C.acento or C.alerta
    local w, h = 520, 118
    local x, y = (W - w) / 2, (H - h) / 2
    color(C.fondo, 0.6 * a); lg.rectangle("fill", 0, 0, W, H)
    color(C.panel, 0.97 * a); lg.rectangle("fill", x, y, w, h, 8, 8)
    local pulso = (AV.apagado or (AV.actual and AV.actual.tipo == "critica")) and (0.55 + 0.45 * math.abs(math.sin(reloj * 4))) or 1
    lg.setLineWidth(3); color(c, a * pulso); lg.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3, 8, 8); lg.setLineWidth(1)
    lg.setFont(F.titulo); color(c, a); lg.printf(titulo, x, y + 16, w, "center")
    lg.setFont(F.normal); color(C.crema, a); lg.printf(texto, x + 24, y + 60, w - 48, "center")
end

-- ── tema guardado ──
local function guardarTema() pcall(love.filesystem.write, "tema.txt", tema) end
local function cambiarTema()
    for i, t in ipairs(ORDEN_TEMAS) do
        if t == tema then tema = ORDEN_TEMAS[i % #ORDEN_TEMAS + 1] break end
    end
    C = TEMAS[tema]
    guardarTema()
    transicion = 0.3
    sonar("abre")
    avisar(T("Tema %s", tema == "fosforo" and T"fósforo" or T"nube"), C.acento, 1.5)
end

-- ── controles (en la consola, gptokeyb traduce el mando a teclas) ──
local TECLAS = {up = "arriba", down = "abajo", left = "izq", right = "der", z = "a", ["return"] = "a",
                x = "b", escape = "b", backspace = "b", c = "y", s = "x", q = "l", w = "r",
                space = "start", rshift = "select", tab = "select"}
local MANDO = {dpup = "arriba", dpdown = "abajo", dpleft = "izq", dpright = "der", a = "a", b = "b", x = "x", y = "y",
               leftshoulder = "l", rightshoulder = "r", start = "start", back = "select"}
local repetir = {boton = nil, espera = 0}
local apretados = {}
local sucio = true   -- pide redibujar la escena guardada en el próximo cuadro
local function presionar(b)
    sucio = true
    apretados[b] = true
    if apretados.start and apretados.select then love.event.quit() return end
    if pregunta then
        if b == "a" then local si = pregunta.si; pregunta = nil; sonar("abre"); si()
        elseif b == "b" then pregunta = nil; sonar("cierra") end
        return
    end
    if b == "select" or b == "y" then cambiarTema() return end
    if E[escena].boton then E[escena].boton(b) end
    if b == "arriba" or b == "abajo" or b == "izq" or b == "der" then repetir.boton, repetir.espera = b, 0.4 end
end
local function soltar(b) apretados[b] = nil; if repetir.boton == b then repetir.boton = nil end end
function love.keypressed(k) if TECLAS[k] then presionar(TECLAS[k]) end end
function love.keyreleased(k) if TECLAS[k] then soltar(TECLAS[k]) end end
local soloTeclado = os.getenv("PULSO_SOLO_TECLADO") == "1"
function love.gamepadpressed(_, b) if not soloTeclado and MANDO[b] then presionar(MANDO[b]) end end
function love.gamepadreleased(_, b) if not soloTeclado and MANDO[b] then soltar(MANDO[b]) end end

-- guion para capturas (desarrollo): PULSO_GUION="espera 2;foto t.png;a;salir"
local guion, guionEspera = {}, 0
local function siguientePaso(dt)
    if #guion == 0 then return end
    guionEspera = guionEspera - dt
    while #guion > 0 and guionEspera <= 0 do
        local paso = table.remove(guion, 1)
        local n, foto = paso:match("^espera%s+([%d%.]+)"), paso:match("^foto%s+(%S+)")
        if n then guionEspera = tonumber(n)
        elseif foto then lg.captureScreenshot(foto); guionEspera = 0.1
        elseif paso == "salir" then love.event.quit()
        else presionar(paso); soltar(paso) end
    end
end

-- ── LÖVE ──
-- ArkOS y dArkOS ponen el procesador en máximo (perfmax) antes de abrir cualquier port, y lo devuelven a normal
-- al cerrarlo (perfnorm). Para un monitor que se deja abierto eso gasta batería: al abrirse, Pulso 36 pasa al
-- último modo elegido en la app (la primera vez, «normal»), si el sistema lo ofrece.
local function aplicarModoGuardado()
    local deseado = (love.filesystem.read("modo.txt") or "interactive"):match("^%s*(%S+)")
    local disponibles = texto(CPU .. "0/cpufreq/scaling_available_governors") or ""
    if not deseado or deseado == D.modo or not (" " .. disponibles .. " "):find(" " .. deseado .. " ", 1, true) then return end
    local nombre, antes = deseado, D.modo
    for _, m in ipairs(MODOS) do if m[2] == deseado then nombre = m[1]:lower() end end
    correr(ACCIONES .. " modo " .. deseado, function(cod)
        if cod == 0 then
            avisar(antes == "performance" and T("Procesador en modo %s (el sistema lo había puesto en máximo).", nombre)
                or T("Procesador en modo %s.", nombre), C.tenue, 4)
        else avisar(T("No se pudo poner el modo %s.", nombre), C.alerta, 4) end
    end)
end
function love.load()
    lg.setDefaultFilter("nearest", "nearest"); lg.setLineStyle("rough")
    F.chica = lg.newFont("fuentes/PixelOperator.ttf", 16, "mono")
    F.normal = lg.newFont("fuentes/PixelOperator-Bold.ttf", 16, "mono")
    F.grande = lg.newFont("fuentes/PixelOperator.ttf", 32, "mono")
    F.titulo = lg.newFont("fuentes/PixelOperator-Bold.ttf", 32, "mono")
    S.tic = tono({1180}, 0.035, 0.10)
    S.abre = tono({587, 880}, 0.2, 0.12)
    S.cierra = tono({440, 330}, 0.16, 0.10)
    S.listo = tono({523, 659, 784, 1047}, 0.5, 0.12)
    S.error = tono({220, 196}, 0.3, 0.12)
    S.alarma = tono({880, 660, 880}, 0.9, 0.16)
    local guardado = love.filesystem.read("tema.txt")
    tema = os.getenv("PULSO_TEMA") or (guardado and TEMAS[guardado] and guardado) or "fosforo"
    C = TEMAS[tema] or TEMAS.fosforo
    local g = os.getenv("PULSO_GUION")
    if g then for paso in g:gmatch("[^;]+") do guion[#guion + 1] = paso:match("^%s*(.-)%s*$") end end
    arrancarSensores()
    recibirSensores(true)
    leerSensores(); actualizarBateria()
    preguntarAyudante()
    ir("tablero")
    aplicarModoGuardado()
    local prueba = os.getenv("PULSO_AVISO")
    if prueba == "baja" then lanzarAviso("baja", T"BATERÍA BAJA", T("Quedan unos %d min. Conecta el cargador pronto.", 30), nil, 3600)
    elseif prueba == "critica" then lanzarAviso("critica", T"BATERÍA CRÍTICA", T("Quedan unos %d min. Guarda tu partida y conecta el cargador.", 10), nil, 3600)
    elseif prueba == "apagado" then AV.apagado, AV.fijo = os.time() + 47, true
    elseif prueba == "cancelado" then lanzarAviso("cancelado", T"CARGADOR CONECTADO", T"La consola ya no se apagará.", nil, 3600) end
end

local seg, cinco, procSeg = 0, 0, 0
function love.update(dt)
    dt = math.min(dt, 1 / 20)
    reloj = reloj + dt
    transicion = suave(transicion, 1, 9, dt)
    fase = fase + dt * (0.9 + (D.carga or 0) * 1.6)        -- más carga, latido más rápido
    seg, cinco = seg + dt, cinco + dt
    recibirSensores()
    if seg >= 1 then seg = 0; leerSensores(); actualizarBateria(); revisarAviso() end
    if cinco >= 5 then cinco = 0; preguntarAyudante(true) end
    procSeg = procSeg + dt
    if (escena == "tablero" or escena == "procesos") and procSeg >= (escena == "procesos" and 1 or 2) then procSeg = 0; leerProcesos() end
    atenderTareas()
    if repetir.boton then
        repetir.espera = repetir.espera - dt
        if repetir.espera <= 0 then
            repetir.espera = 0.09
            if E[escena].boton and not pregunta then E[escena].boton(repetir.boton) end
        end
    end
    siguientePaso(dt)
end

-- La escena (fondo, recuadros, textos, gráficas) se dibuja 4 veces por segundo en un lienzo, o al apretar un botón;
-- en cada cuadro solo se pega ese lienzo y se dibuja lo que se mueve: corazón, electrocardiograma y barrido.
local lienzoEscena, ultimaEscena = nil, -1
function love.draw()
    local e = salida(limitar(transicion, 0, 1))
    local animando = transicion < 0.999
    lienzoEscena = lienzoEscena or lg.newCanvas(W, H)
    local ocupado = E.almacenamiento.calculando or E.red.probando or E.red.trabajando or E.memoria.trabajando
        or E.procesador.trabajando or E.procesos.trabajando or E.energia.trabajando
    if sucio or animando or (ocupado and reloj - ultimaEscena >= 1 / 15) or reloj - ultimaEscena >= 0.25 then
        sucio, ultimaEscena = false, reloj
        lg.setCanvas(lienzoEscena)
        fondo()
        lg.push(); lg.translate(0, (1 - e) * 12)
        E[escena].dibujar()
        lg.pop()
        lg.setCanvas()
    end
    lg.setColor(1, 1, 1); lg.draw(lienzoEscena)
    lg.push(); lg.translate(0, (1 - e) * 12)
    corazon(F.titulo:getWidth("Pulso 36") + 40, 30, 3)
    ecg(232, 10, 250, 40)
    lg.pop()
    if animando then color(C.fondo, (1 - e) * 0.8); lg.rectangle("fill", 0, 0, W, H) end
    dibujarAviso()
    dibujarPregunta()
    dibujarToast()
    barrido()
end

-- Bucle a 30 cuadros por segundo: el tablero cambia una vez por segundo y las animaciones se ven igual de suaves;
-- el tiempo sobrante se duerme (antes iba a 60 con vsync y usaba casi un núcleo entero).
local FPS = tonumber(os.getenv("PULSO_FPS") or "") or 30
function love.run()
    love.load(love.arg.parseGameArguments(arg), arg)
    love.timer.step()
    local paso = 1 / FPS
    -- desarrollo: PULSO_GRABAR=1 guarda cada cuadro (g00001.png…) con un paso fijo de 1/30 s, para armar un video
    local grabar, cuadro = os.getenv("PULSO_GRABAR") == "1", 0
    return function()
        local inicio = love.timer.getTime()
        love.event.pump()
        for nombre, a, b, c, d, e, f in love.event.poll() do
            if nombre == "quit" and not (love.quit and love.quit()) then return a or 0 end
            love.handlers[nombre](a, b, c, d, e, f)
        end
        local dt = love.timer.step()
        love.update(grabar and (1 / 30) or dt)
        if lg.isActive() then
            lg.origin(); lg.clear(lg.getBackgroundColor())
            love.draw()
            if grabar then cuadro = cuadro + 1; lg.captureScreenshot(string.format("g%05d.png", cuadro)) end
            lg.present()
        end
        local dur = love.timer.getTime() - inicio
        if dur > 0.25 then print(string.format("%s cuadro lento: %d ms en %s", os.date("%H:%M:%S"), dur * 1000, escena)); io.stdout:flush() end
        local resto = paso - (love.timer.getTime() - inicio)
        if resto > 0 then love.timer.sleep(resto) end
    end
end

if os.getenv("PULSO_MEDIR") then function love.quit() print(string.format("CPU %.2f s", os.clock())) end end

-- Desarrollo: PULSO_TEXTOS=1 anota cada texto distinto que se dibuja y al salir lo guarda en textos-vistos.txt (en la
-- carpeta de guardado de LÖVE). Sirve para comparar dos versiones sin depender de la hora ni de los datos en vivo.
if os.getenv("PULSO_TEXTOS") then
    local vistos, print0, printf0 = {}, lg.print, lg.printf
    local function anotar(t) if type(t) == "string" or type(t) == "number" then vistos[tostring(t)] = true end end
    lg.print = function(t, ...) anotar(t); return print0(t, ...) end
    lg.printf = function(t, ...) anotar(t); return printf0(t, ...) end
    local quitAntes = love.quit
    function love.quit()
        local l = {}
        for k in pairs(vistos) do l[#l + 1] = (k:gsub("\n", "\\n")) end
        table.sort(l)
        love.filesystem.write("textos-vistos.txt", table.concat(l, "\n") .. "\n")
        if quitAntes then return quitAntes() end
    end
end

-- Cualquier error queda escrito en el registro (en la consola: ports/pulso36/conf/log.txt) antes de la pantalla
-- de error de LÖVE, que no lo imprime.
local errorOriginal = love.errorhandler
function love.errorhandler(msg)
    print(os.date("%H:%M:%S") .. " ERROR: " .. tostring(msg) .. "\n" .. debug.traceback("", 2)); io.stdout:flush()
    return errorOriginal(msg)
end
