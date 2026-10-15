import json
from pathlib import Path
from decimal import Decimal as D, getcontext
getcontext().prec=90
data=json.load((Path(__file__).parent / 'candidates.json').open())
def vec(c,t):
 p=[[D.from_float(v) for v in a] for a in c]
 while len(p)>1:p=[[(1-t)*a+t*b for a,b in zip(p[i],p[i+1])] for i in range(len(p)-1)]
 return p[0]
def deriv(c,t):
 p=[[3*(D.from_float(b)-D.from_float(a)) for a,b in zip(c[i],c[i+1])] for i in range(3)]
 while len(p)>1:p=[[(1-t)*a+t*b for a,b in zip(p[i],p[i+1])] for i in range(len(p)-1)]
 return p[0]
for name,c in data.items():
 print('\n'+name)
 for h in c['experiment']:
  t,u=map(D.from_float,(h['t'],h['u']));a,b=vec(c['a'],t),vec(c['b'],u)
  residual=sum((x-y)**2 for x,y in zip(a,b)).sqrt()
  added=not any(h['t']==v['t'] and h['u']==v['u'] for v in c['baseline'])
  print('ADD' if added else 'OLD',f't={t:.17g} u={u:.17g} separation={residual:.7E}')
  if name=='shared' and added:
   for i in range(120):
    a,b=vec(c['a'],t),vec(c['b'],u); da,db=deriv(c['a'],t),deriv(c['b'],u)
    f,g=a[0]-b[0],a[1]-b[1]; det=da[1]*db[0]-da[0]*db[1]
    if not det:break
    dt=(-f*db[1]+g*db[0])/det;du=(da[0]*g-da[1]*f)/det
    t-=dt;u-=du
    if i in [0,9,29,59,119]:print(' Newton',i+1,'1-t',f'{1-t:.8E}','u',f'{u:.8E}')
