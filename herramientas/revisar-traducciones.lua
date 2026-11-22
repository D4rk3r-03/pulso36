-- Revisa que cada texto fijo de la interfaz (T"…" y T("…", …) en main.lua) tenga traducción en textos.lua.
-- Uso (desde la raíz del repositorio): luajit herramientas/revisar-traducciones.lua
package.path = "pulso36/juego/?.lua;" .. package.path
local textos = require("textos")
local f = assert(io.open("pulso36/juego/main.lua", "r"))
local lineas = {}
for l in f:lines() do lineas[#lineas + 1] = (l:gsub("^%s*%-%-.*$", "")) end   -- sin comentarios de línea entera
f:close()
local codigo = table.concat(lineas, "\n")
local faltan, vistos, total = {}, {}, 0
local function revisar(s)
    if vistos[s] then return end
    vistos[s] = true
    total = total + 1
    if not textos.en[s] then faltan[#faltan + 1] = s end
end
for s in codigo:gmatch('%f[%w_]T"(.-[^\\])"') do revisar(s) end
for s in codigo:gmatch('%f[%w_]T%("(.-[^\\])"') do revisar(s) end
if #faltan > 0 then
    print(#faltan .. " de " .. total .. " textos sin traducción al inglés:")
    for _, s in ipairs(faltan) do print("  " .. s) end
    os.exit(1)
end
print("Traducciones completas: " .. total .. " textos.")
