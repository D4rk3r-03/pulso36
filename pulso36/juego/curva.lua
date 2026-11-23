-- Pulso 36 · curva de descarga de referencia, armada con el registro de la batería.
-- Cada punto lleva los mAh que aún quedaban hasta que la consola se apagó sola (p.resta) y el voltaje suavizado.
--
-- 1. Base: la descarga completa más nueva que empezó alta (>= 4,05 V) y terminó apagándose sola (< 3,42 V). Si no
--    hay ninguna así, la completa más nueva.
-- 2. Si la base no llega arriba, se «cose» por encima otra descarga más alta que baje hasta el voltaje donde
--    empieza la base (aunque no haya terminado apagándose): en el punto de unión se toman los mAh que la base dice
--    que quedaban, y desde ahí se suma hacia arriba lo que gastó esa descarga. Se repite hasta llegar a 4,05 V.
-- Así una descarga corta (p. ej. 3,59 → 3,33 V) ya no deja la parte alta como una recta inventada.
local M = {}

M.ALTA, M.APAGADO, M.MIN_FILAS = 4050, 3420, 20

local function suavizar(b)   -- voltaje suavizado (5 puntos): el de un minuto suelto salta con la carga
    if b.suavizada then return end
    for k = 1, #b do
        local s, n = 0, 0
        for j = math.max(1, k - 2), math.min(#b, k + 2) do s = s + b[j].mv; n = n + 1 end
        b[k].suave = s / n
    end
    b.suavizada = true
end

-- mAh que quedaban a ese voltaje según los puntos (de más alto a más bajo); nil si está por encima del primero
function M.resta(pts, mv)
    if not pts or #pts == 0 or mv > pts[1].suave then return nil end
    for k = 2, #pts do
        if pts[k].suave <= mv then
            local a, c = pts[k - 1], pts[k]
            local f = (a.suave - mv) / math.max(1, a.suave - c.suave)
            return a.resta + (c.resta - a.resta) * f
        end
    end
    return 0
end

-- bloques: descargas en orden (cada una, filas {t, mv, ma}; .cerrada si después vino una carga)
-- devuelve la base (descarga completa real) y los puntos de la curva (cosida), o nil
function M.descarga(bloques, ahora, soloUltima)
    local utiles, completas = {}, {}
    for i = #bloques, 1, -1 do   -- de la más nueva a la más vieja
        local b = bloques[i]
        local terminada = b.cerrada or (#b > 0 and ahora - b[#b].t > 15 * 60)
        if #b >= M.MIN_FILAS and terminada then
            suavizar(b)
            utiles[#utiles + 1] = b
            if b[#b].mv < M.APAGADO then completas[#completas + 1] = b end
        end
    end
    local base = nil
    if not soloUltima then for _, b in ipairs(completas) do if b[1].suave >= M.ALTA then base = b; break end end end
    base = base or completas[1]
    if not base then return nil end

    local pts = {}
    base[#base].resta = 0
    for k = #base - 1, 1, -1 do
        local dt = base[k + 1].t - base[k].t
        base[k].resta = base[k + 1].resta + ((dt > 0 and dt < 1800) and base[k].ma * dt / 3600 or 0)
    end
    for k = 1, #base do pts[k] = {t = base[k].t, mv = base[k].mv, ma = base[k].ma, suave = base[k].suave, resta = base[k].resta} end

    local cosidas, usadas = 0, {[base] = true}
    while not soloUltima and pts[1].suave < M.ALTA do
        local tope, otra, union = pts[1].suave, nil, nil
        for _, b in ipairs(utiles) do
            if not usadas[b] and b[1].suave > tope + 30 then
                for k = 2, #b do if b[k].suave <= tope then otra, union = b, k; break end end
                if otra then break end
            end
        end
        if not otra then break end
        usadas[otra] = true
        local nuevos = {}
        nuevos[union] = {t = otra[union].t, mv = otra[union].mv, ma = otra[union].ma, suave = otra[union].suave,
                         resta = M.resta(pts, otra[union].suave)}
        for k = union - 1, 1, -1 do
            local dt = otra[k + 1].t - otra[k].t
            nuevos[k] = {t = otra[k].t, mv = otra[k].mv, ma = otra[k].ma, suave = otra[k].suave,
                         resta = nuevos[k + 1].resta + ((dt > 0 and dt < 1800) and otra[k].ma * dt / 3600 or 0)}
        end
        for _, p in ipairs(pts) do if p.suave < nuevos[union].suave then nuevos[#nuevos + 1] = p end end
        pts, cosidas = nuevos, cosidas + 1
    end
    return base, pts, cosidas
end

return M
