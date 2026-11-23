-- Compara la curva de referencia vieja (solo la última descarga completa) con la cosida, sobre un registro real.
-- Arma las dos con los datos anteriores al corte y les pide predecir la primera descarga después del corte.
-- Uso: luajit herramientas/comparar-curvas.lua registro-AAAA-MM.csv "AAAA-MM-DD HH:MM:SS"
local aqui = (arg[0]:match("^(.*)/[^/]*$") or ".")
package.path = aqui .. "/../pulso36/juego/?.lua;" .. package.path
local CURVA = require("curva")
local archivo, corte = arg[1], arg[2]
local CAP = 3000
local function tiempo(f) local y,mo,d,h,mi,s = f:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"); return os.time{year=y,month=mo,day=d,hour=h,min=mi,sec=s} end
local tc = tiempo(corte)
local antes, despues, actual = {}, {}, nil
for l in io.lines(archivo) do
  local fecha, estado, mv, ma = l:match("^(%d+%-%d+%-%d+ %d+:%d+:%d+),([^,]+),%d+,(%d+),(%-?%d+)")
  if fecha then
    local t = tiempo(fecha); local lista = t < tc and antes or despues
    if estado == "Discharging" then
      if not actual or actual.lista ~= lista then actual = {lista = lista}; lista[#lista + 1] = actual end
      actual[#actual + 1] = {t = t, mv = tonumber(mv), ma = math.abs(tonumber(ma))}
    else if actual then actual.cerrada = true end; actual = nil end
  end
end
local function restaTotal(pts, mv)   -- como restaPorVoltaje de Pulso (arriba del tope, recta hasta 4,15 V)
  if mv >= pts[1].suave then return pts[1].resta + (CAP - pts[1].resta) * math.min(1, (mv - pts[1].suave) / math.max(1, 4150 - pts[1].suave)) end
  return CURVA.resta(pts, mv)
end
local _, viejo = CURVA.descarga(antes, tc, true)
local base, nuevo, cos = CURVA.descarga(antes, tc)
print(string.format("Curva vieja: %d → %d mV (%d puntos)", viejo[1].mv, viejo[#viejo].mv, #viejo))
print(string.format("Curva nueva: %d → %d mV (%d puntos, %d descarga(s) cosida(s))", nuevo[1].mv, nuevo[#nuevo].mv, #nuevo, cos))
print("\nVoltaje   vieja         nueva")
for _, mv in ipairs{4150, 4100, 4050, 4000, 3950, 3900, 3850, 3800, 3750, 3700, 3650, 3600, 3550, 3500, 3450, 3400} do
  local a, b = restaTotal(viejo, mv), restaTotal(nuevo, mv)
  print(string.format("%.2f V   %4d mAh %3d%%  %4d mAh %3d%%", mv/1000, a, a/CAP*100+0.5, b, b/CAP*100+0.5))
end
-- prueba: la primera descarga después del corte
local d = despues[1]
for k = 1, #d do local s, n = 0, 0; for j = math.max(1,k-2), math.min(#d,k+2) do s = s + d[j].mv; n = n + 1 end; d[k].suave = s/n end
local usado = 0
for k = 2, #d do local dt = d[k].t - d[k-1].t; if dt > 0 and dt < 1800 then usado = usado + d[k-1].ma * dt / 3600 end end
local v0, v1 = d[3].suave, d[#d-2].suave
print(string.format("\nPrueba: descarga del %s, %.0f → %.0f mV, gastó de verdad %.0f mAh", os.date("%d/%m %H:%M", d[1].t), v0, v1, usado))
for nom, pts in pairs{vieja = viejo, nueva = nuevo} do
  local p = restaTotal(pts, v0) - restaTotal(pts, v1)
  print(string.format("  curva %-5s predice %4.0f mAh  → error %+4.0f mAh (%+.0f %%)", nom, p, p - usado, (p - usado) / usado * 100))
end
print("\nA lo largo de esa descarga: gasto real desde el inicio vs. lo que predice cada curva")
print("Voltaje   real    vieja (error)    nueva (error)")
local acum, k0 = 0, 3
local maxv, maxn = 0, 0
for _, obj in ipairs{3950, 3900, 3850, 3800, 3750, 3700, 3650, 3600, 3550} do
  local u = 0
  for k = 2, #d do
    local dt = d[k].t - d[k-1].t; if dt > 0 and dt < 1800 then u = u + d[k-1].ma * dt / 3600 end
    if d[k].suave <= obj then break end
  end
  local pv = restaTotal(viejo, v0) - restaTotal(viejo, obj)
  local pn = restaTotal(nuevo, v0) - restaTotal(nuevo, obj)
  maxv, maxn = math.max(maxv, math.abs(pv-u)), math.max(maxn, math.abs(pn-u))
  print(string.format("%.2f V  %5.0f   %5.0f (%+4.0f)    %5.0f (%+4.0f)", obj/1000, u, pv, pv-u, pn, pn-u))
end
print(string.format("Error máximo: vieja %.0f mAh (%.0f %% de la batería) · nueva %.0f mAh (%.0f %%)", maxv, maxv/CAP*100, maxn, maxn/CAP*100))
