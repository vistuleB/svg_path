"""80-digit circle intersections from the SVG endpoints/radii, independent of our solver."""
from decimal import Decimal as D, localcontext
from pathlib import Path
import json,math
root=Path(__file__).parent
pair=json.loads((root/'remaining-continuity-4295-pair.json').read_text())
def dec(x):return D.from_float(x)
with localcontext() as ctx:
 ctx.prec=80
 def circle(s):
  x,y=map(dec,(s['start']['x'],s['start']['y']));u,v=map(dec,(s['end']['x'],s['end']['y']));r=dec(s['radius']['x'])
  dx,dy=u-x,v-y;k=(r*r/(dx*dx+dy*dy)-D('0.25')).sqrt()
  # For a minor arc, positive SVG sweep places the center left of its chord.
  if not s['sweep']:k=-k
  return ((x+u)/2-dy*k,(y+v)/2+dx*k,r)
 a,b=circle(pair['curved']),circle(pair['cutter']);dx,dy=b[0]-a[0],b[1]-a[1];d=(dx*dx+dy*dy).sqrt();along=(a[2]**2-b[2]**2+d*d)/(2*d);height=(a[2]**2-along*along).sqrt();base=(a[0]+along*dx/d,a[1]+along*dy/d)
 witnesses=[]
 for sign in [-1,1]:
  p=(base[0]-sign*height*dy/d,base[1]+sign*height*dx/d);ts=[]
  for s,c in zip([pair['curved'],pair['cutter']],[a,b]):
   angle=lambda q:math.atan2(float(q[1]-c[1]),float(q[0]-c[0]))
   start=angle((dec(s['start']['x']),dec(s['start']['y'])));end=angle((dec(s['end']['x']),dec(s['end']['y'])));theta=angle(p)
   if s['sweep']:delta=(end-start)%(2*math.pi);travel=(theta-start)%(2*math.pi)
   else:delta=(start-end)%(2*math.pi);travel=(start-theta)%(2*math.pi)
   ts.append(travel/delta)
  witnesses.append({'point':{'x':float(p[0]),'y':float(p[1])},'decimalPoint':[str(x) for x in p],'left_t':ts[0],'right_t':ts[1],'insideBoth':all(0<t<1 for t in ts)})
 report={'precision':80,'centers':[[str(x) for x in c] for c in [a,b]],'witnesses':witnesses}
(root/'remaining-continuity-4295-analytic.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(witnesses,indent=2))
