"""Exact-binary-input circle centers, evaluated with 80-digit Decimal."""
from decimal import Decimal as D, localcontext
from pathlib import Path
import json
record=json.loads((Path(__file__).parent/'offset-arc-reparameterization.json').read_text())
def center(a):
 ax,ay,bx,by=map(D,[a['start']['x'],a['start']['y'],a['end']['x'],a['end']['y']])
 rx=D(a['radius']['x']); dx=bx-ax;dy=by-ay;length=(dx*dx+dy*dy).sqrt()
 height=(rx*rx-length*length/4).sqrt(); k=height/length
 return ((ax+bx)/2+dy*k,(ay+by)/2-dx*k)
with localcontext() as ctx:
 ctx.prec=80
 a=center(record['arc']);b=center(record['tail'])
 result={'precision':80,'originalCenter':list(map(str,a)),'tailCenter':list(map(str,b)), 'centerSeparation':str(((a[0]-b[0])**2+(a[1]-b[1])**2).sqrt())}
 print(json.dumps(result,indent=2))
