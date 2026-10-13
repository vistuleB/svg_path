"""Bound reported overlap witnesses with 80-digit Decimal arithmetic.

Usage: python3 scripts/paperjs/check-overlap-witnesses.py REPORT OUTPUT
The report is produced by investigate-boolean-errors.mjs. This checks the
reported blocker, not successful CSG equivalence or absence of later failures.
"""
import json,math,sys
from decimal import Decimal as D, getcontext
getcontext().prec=80
def norm(a):return sum(x*x for x in a).sqrt()
def dist(a,b):return norm([x-y for x,y in zip(a,b)])
p=sys.argv[1]
def pts(s):
 if s['type']=='Line':
  a,b=tuple(D(s['start'][v]) for v in ('x','y')),tuple(D(s['end'][v]) for v in ('x','y'));return [a,lerp(a,b,D(1)/3),lerp(a,b,D(2)/3),b]
 return [tuple(D(s[k][v]) for v in ('x','y')) for k in ('start','control1','control2','end')]
def lerp(a,b,t):return tuple(x*(1-t)+y*t for x,y in zip(a,b))
def split(p,t):
 a=[lerp(p[i],p[i+1],t) for i in range(3)];b=[lerp(a[i],a[i+1],t) for i in range(2)];c=lerp(*b,t);return [p[0],a[0],b[0],c],[c,b[1],a[2],p[3]]
def trim(p,a,b):
 if a>b:return trim(p,b,a)[::-1]
 q=split(p,b)[0];return split(q,a/b)[1] if b else [p[0]]*4
def point(p,t):return split(p,t)[0][-1]
rows=[]
for r in json.load(open(p))['results']:
 t=[t for t in r['trace'] if t['kind']=='non-affine']
 if not t:continue
 x=t[-1];L,R=pts(x['left']),pts(x['right']);tol=D(x['tolerance']);w=[]
 for ca in x['candidates']['non_affine']:
  a,b,c,d=map(D,ca[:4]);l,rr=trim(L,a,b),trim(R,c,d);v=[l[-1][k]-l[0][k] for k in [0,1]];n=norm(v)
  if not n:continue
  # Each curve lies within its control polygon's transverse bound.
  transverse=max(abs(v[0]*(q[1]-l[0][1])-v[1]*(q[0]-l[0][0]))/n for q in l+rr)
  projs=[[sum((q[k]-l[0][k])*v[k] for k in [0,1])/n for q in pp] for pp in [l,rr]]
  crosses=[[ (v[0]*(q[1]-l[0][1])-v[1]*(q[0]-l[0][0]))/n for q in pp] for pp in [l,rr]]
  transverse_gap=max(abs(max(crosses[0])-min(crosses[1])),abs(max(crosses[1])-min(crosses[0])))
  axial_gap=max(abs(projs[0][0]-projs[1][0]),abs(projs[0][-1]-projs[1][-1]))
  hausdorff_bound=norm([transverse_gap,axial_gap])
  monotone=all(all(p[i+1]>=p[i] for i in range(3)) for p in projs)
  gap=max(dist(l[0],rr[0]),dist(l[-1],rr[-1]));mis=max(dist(point(l,t),point(rr,t)) for t in [D(".25"),D(".5"),D(".75")])
  w.append(dict(domain=[a,b,c,d],transverse=transverse,monotone=monotone,endpointGap=gap,geometryDistanceBound=hausdorff_bound,affineMismatch=mis,certified=monotone and hausdorff_bound+D("1e-60")<tol and mis>tol+D("1e-60")))
 best=next((z for z in w if z['certified']),min(w,key=lambda z:z['transverse']))
 rows.append(dict(id=r['id'],tolerance=tol,witness=best,pair={k:x[k] for k in ['left','right']}))
 print(r['id'],best['certified'],f"perp={best['transverse']:.3g}",best['monotone'],f"gap={best['endpointGap']:.3g}",f"mismatch={best['affineMismatch']:.3g}")
json.dump(rows,open(sys.argv[2],'w'),indent=2,default=lambda x:float(x))
