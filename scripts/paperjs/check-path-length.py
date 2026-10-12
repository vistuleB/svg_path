"""Independent Decimal adaptive Simpson check of upstream Path#length fixture."""
import json
from decimal import Decimal as D, getcontext
from pathlib import Path
getcontext().prec=50
root=Path(__file__).resolve().parent
b=json.loads((root/'paths.json').read_text())['blocks'][0]
o=b['operations'][2]; c=list(map(D.from_float,o['curve']))
def speed(t):
    v=[3*(1-t)**2*(c[2+i]-c[i])+6*(1-t)*t*(c[4+i]-c[2+i])+3*t*t*(c[6+i]-c[4+i]) for i in [0,1]]
    return (v[0]*v[0]+v[1]*v[1]).sqrt()
def integral(end,eps):
    def rec(a,b,fa,fm,fb,whole,tol,depth):
        mid=(a+b)/2;fl=speed((a+mid)/2);fr=speed((mid+b)/2)
        left=(mid-a)*(fa+4*fl+fm)/6;right=(b-mid)*(fm+4*fr+fb)/6
        delta=left+right-whole
        if abs(delta)<=15*tol:return left+right+delta/15
        if not depth:raise RuntimeError('Integration depth exhausted')
        return rec(a,mid,fa,fl,fm,left,tol/2,depth-1)+rec(mid,b,fm,fr,fb,right,tol/2,depth-1)
    a=D(0);b=D(end);fa=speed(a);fb=speed(b);fm=speed((a+b)/2)
    return rec(a,b,fa,fm,fb,(b-a)*(fa+4*fm+fb)/6,D(eps),30)
target=D.from_float(o['distance']);results=[]
probe=json.loads((root/'path-screening.json').read_text())
got=next(r for r in probe if r['block']==0 and r['method']=='getTimeAt')['result']['0']
for eps in ['1e-14','1e-18']:
    results.append({'integrationTolerance':eps,'length':str(integral(1,eps)),
      'gleamDistanceResidual':str(integral(D.from_float(got),eps)-target),
      'upstreamExpectedDistanceResidual':str(integral(D.from_float(b['assertions'][1]['expected']),eps)-target)})
(root/'path-length-findings.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
