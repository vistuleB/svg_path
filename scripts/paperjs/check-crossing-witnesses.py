"""Independently bisect the captured projected cubic using 80-digit arithmetic.
Usage: python3 scripts/paperjs/check-crossing-witnesses.py REPORT OUTPUT
"""
import json,sys
from decimal import Decimal as D,localcontext
p=sys.argv[1];out=[]
with localcontext() as ctx:
 ctx.prec=80
 for r in json.load(open(p))['results']:
  if not any(x['kind']=='crossing-error' for x in r['trace']):continue
  x=[x for x in r['trace'] if x['kind']=='crossing-error'][-1];c=x['context'];v=[D(z) for z in c['controlValues']]
  def f(t):
   q=v[:]
   while len(q)>1:q=[a*(1-t)+b*t for a,b in zip(q,q[1:])]
   return q[0]
  lo=D(0);hi=D(1) if v[-1]!=0 else D(1)-D('1e-12');assert f(lo)*f(hi)<0
  for _ in range(250):
   mid=(lo+hi)/2
   if f(lo)*f(mid)<=0:hi=mid
   else:lo=mid
  root=(lo+hi)/2;fr=float(root);gap=min(abs(root-D(c['lower'])),abs(root-D(c['upper'])))
  row=dict(id=r['id'],context=c,reportedResidual=x['value'],trueInteriorRoot=str(root),floatRoot=fr,bernsteinResidualAtFloatRoot=str(f(D(fr))),rootInsideWindow=D(c['lower'])<=root<=D(c['upper']),distanceToWindow=str(gap),hasExactEndpointRoot=v[-1]==0)
  out.append(row);print(r['id'],str(root)[:30],row['rootInsideWindow'],row['bernsteinResidualAtFloatRoot'])
json.dump(out,open(sys.argv[2],"w"),indent=2)
