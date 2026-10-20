from pathlib import Path
from decimal import Decimal as D,getcontext
import json, math
getcontext().prec=80
root=Path(__file__).resolve().parent
base=json.loads((root/'semicircle-accuracy-baseline.json').read_text())
fixed=json.loads((root/'semicircle-accuracy-compensated.json').read_text())
rows=[]
for old,new in zip(base,fixed):
 x,y=map(D,old['start']);u,v=map(D,old['end']);rx,ry=D(old['rx']),D(old['ry'])
 dx,dy=(x-u)/2,(y-v)/2
 gap=rx*rx*ry*ry-rx*rx*dy*dy-ry*ry*dx*dx
 den=rx*rx*dy*dy+ry*ry*dx*dx
 c=(max(D(0),gap)/den).sqrt()*(1 if old['sweep'] else -1)
 center=[(x+u)/2+c*rx*dy/ry,(y+v)/2-c*ry*dx/rx]
 def err(row):
  actual=[D(row['actual']['center'][k]) for k in ['x','y']]
  return sum((a-b)**2 for a,b in zip(actual,center)).sqrt()
 # Axis-aligned extrema; cardinal angles are well separated from the ends
 # in these fixtures. Only angle membership uses binary64 arithmetic.
 factor=max(D(1),dx*dx/(rx*rx)+dy*dy/(ry*ry)).sqrt()
 erx,ery=rx*factor,ry*factor
 start=math.atan2(float((y-center[1])/ery),float((x-center[0])/erx))
 end=math.atan2(float((v-center[1])/ery),float((u-center[0])/erx))
 sign=1 if old['sweep'] else -1
 delta=(sign*(end-start))%(2*math.pi)
 candidates=[(x,y),(u,v)]
 for angle,pnt in [(0,(center[0]+erx,center[1])),(math.pi/2,(center[0],center[1]+ery)),(math.pi,(center[0]-erx,center[1])),(3*math.pi/2,(center[0],center[1]-ery))]:
  if (sign*(angle-start))%(2*math.pi)<=delta:candidates.append(pnt)
 expected={'min':dict(x=min(p[0] for p in candidates),y=min(p[1] for p in candidates)), 'max':dict(x=max(p[0] for p in candidates),y=max(p[1] for p in candidates))}
 def bound_error(row):return max(abs(D(row['bounds'][side][axis])-expected[side][axis]) for side in ['min','max'] for axis in ['x','y'])
 rows.append(dict(id=old['id'],scale=old['scale'],ratio=old['ratio'],svg_center=[str(x) for x in center],baseline_error=str(err(old)),compensated_error=str(err(new)),radius_enlarged=gap<0,baseline_bounds_error=str(bound_error(old)),compensated_bounds_error=str(bound_error(new))))
print(json.dumps(rows,indent=2))
