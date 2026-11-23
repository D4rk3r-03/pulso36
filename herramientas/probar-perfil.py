import sys, datetime as dt, math
BIN=10; VIDA=30*86400  # vida media del peso: 30 días
def leer(archivos):
    filas={}
    for f in archivos:
        for l in open(f):
            p=l.strip().split(',')
            if len(p)>4 and p[3].isdigit(): filas[p[0]]=p   # junta SDs; misma fecha = misma fila
    out=[]
    for k in sorted(filas):
        p=filas[k]; out.append((dt.datetime.strptime(k,'%Y-%m-%d %H:%M:%S').timestamp(),p[1],int(p[3]),abs(int(p[4]))))
    return out
def segmentos(filas):
    seg=[];cur=None
    for t,st,mv,ma in filas:
        if st=='Discharging':
            if cur is None: cur=[]; seg.append(cur)
            cur.append([t,mv,ma])
        else: cur=None
    for s in seg:
        for k in range(len(s)):
            v=[s[j][1] for j in range(max(0,k-2),min(len(s),k+3))]; s[k].append(sum(v)/len(v))
    return [s for s in seg if len(s)>=20]
def perfil(segs, ahora):
    suma={}; peso={}
    for s in segs:
        w=0.5**((ahora-s[-1][0])/VIDA)
        m=1e9; acum={}
        for k in range(1,len(s)):
            dtt=s[k][0]-s[k-1][0]
            m=min(m,s[k-1][3])
            if 0<dtt<1800: b=int(m//BIN); acum[b]=acum.get(b,0)+s[k-1][2]*dtt/3600
        if not acum: continue
        bs=sorted(acum); 
        for b in bs[1:-1]:   # franjas completas (sin la primera ni la última)
            suma[b]=suma.get(b,0)+acum[b]*w; peso[b]=peso.get(b,0)+w
    return {b:suma[b]/peso[b] for b in suma}
def usado(P,v1,v0):  # mAh entre v1 y v0 (v0 > v1)
    tot=0
    for b,x in P.items():
        lo,hi=b*BIN,(b+1)*BIN
        a=max(lo,v1); c=min(hi,v0)
        if c>a: tot+=x*(c-a)/BIN
    return tot
def probar(nombre, archivos, archivoPrueba, corte):
    tc=dt.datetime.strptime(corte,'%Y-%m-%d %H:%M:%S').timestamp()
    todas=leer(archivos)
    P=perfil(segmentos([f for f in todas if f[0]<tc]), tc)
    prueba=[s for s in segmentos([f for f in leer([archivoPrueba]) if f[0]>=tc])][0]
    v0=prueba[2][3]; err=0; filas=[]
    fin=min(x[3] for x in prueba)
    for obj in [o for o in (3950,3900,3850,3800,3750,3700,3650,3600,3550) if o > fin]:
        u=0
        for k in range(1,len(prueba)):
            d=prueba[k][0]-prueba[k-1][0]
            if 0<d<1800: u+=prueba[k-1][2]*d/3600
            if prueba[k][3]<=obj: break
        p=usado(P,obj,v0); err=max(err,abs(p-u)); filas.append((obj,u,p))
    print(f"{nombre}: error máximo {err:.0f} mAh ({err/30:.0f} %)   capacidad del perfil 3,40→4,15 V: {usado(P,3400,4150):.0f} mAh")
    return filas
# Uso: python3 herramientas/probar-perfil.py registro-sd1.csv registro-sd2.csv
D=sys.argv[1]; A=sys.argv[2]
print("Prueba dArkOS (predice la descarga del 23/11 06:48):")
probar("  perfil solo SD dArkOS", [D], D, "2026-11-23 06:00:00")
probar("  perfil con las dos SD", [D,A], D, "2026-11-23 06:00:00")
print("Prueba ArkOS (predice la descarga del 22/11 17:43):")
probar("  perfil solo SD ArkOS ", [A], A, "2026-11-22 17:00:00")
probar("  perfil con las dos SD", [D,A], A, "2026-11-22 17:00:00")
