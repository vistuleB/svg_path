"""Decimal circle intersections for the two exact binary64 SVG arc inputs."""
from decimal import Decimal as D, localcontext
from pathlib import Path
import json
root=Path(__file__).resolve().parent
arcs=json.loads((root/'tangent-timeout-original-pair.json').read_text())
with localcontext() as ctx:
 ctx.prec=80
 def center(s):
  x,y=D(s['start']['x']),D(s['start']['y']);u,v=D(s['end']['x']),D(s['end']['y']);r=D(s['radius']['x'])
  dx=(x-u)/2;dy=(y-v)/2;q=dx*dx+dy*dy
  factor=((r*r-q)/q).sqrt()*(-1 if s['large_arc']==s['sweep'] else 1)
  return ((x+u)/2+factor*dy,(y+v)/2-factor*dx,r)
 a,b=map(center,arcs);dx=b[0]-a[0];dy=b[1]-a[1];d=(dx*dx+dy*dy).sqrt();along=(a[2]*a[2]-b[2]*b[2]+d*d)/(2*d);h2=a[2]*a[2]-along*along
 mx=a[0]+along*dx/d;my=a[1]+along*dy/d
 roots=[(mx-sign*h2.sqrt()*dy/d,my+sign*h2.sqrt()*dx/d) for sign in [-1,1]] if h2>=0 else []
 record={'precision':80,'input':'Exact Decimal.from_float equivalent conversion of captured binary64 values; circular SVG endpoint-center formula, then circle-circle intersection. Roots lie within both quarter arcs.','centers':a[:2]+b[:2],'radius':a[2],'height_squared':h2,'roots':roots}
 (root/'tangent-timeout-circle-oracle.json').write_text(json.dumps(record,default=str,indent=2)+'\n')
 print(json.dumps(record,default=str,indent=2))
