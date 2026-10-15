"""Inspect saved arrangement rotations without changing library code."""
import json, math
from pathlib import Path
from functools import cmp_to_key
from fractions import Fraction
root=Path(__file__).parent
reports=[]
for row in json.loads((root/'remaining-topology-snapshots.json').read_text())['rows']:
 g=row['result'];edges={e['id']:e for e in g['edges']};vertices={v['id']:v for v in g['vertices']}
 orders={o['id']:[(d['edge_id'],d['reversed']) for group in o['groups'] for d in group] for o in g['orders']}
 def walks(order):
  todo={(e,rev) for e in edges for rev in (False,True)};result=[]
  while todo:
   first=min(todo);d=first;walk=[]
   while d in todo:
    todo.remove(d);walk.append(d);e=edges[d[0]];v=e['start_vertex'] if d[1] else e['end_vertex'];seq=order[v];i=seq.index((d[0],not d[1]));d=seq[(i+1)%len(seq)]
   assert d==first
   result.append(walk)
  return result
 def vector(d,mode):
  e=edges[d[0]]
  if mode=='vertex':a=vertices[e['start_vertex']]['point'];b=vertices[e['end_vertex']]['point']
  else:a=e['segment']['start'];b=e['segment']['end']
  if d[1]:a,b=b,a
  return (Fraction(b['x'])-Fraction(a['x']),Fraction(b['y'])-Fraction(a['y']))
 def cmp(a,b,mode):
  x,y=vector(a,mode);u,v=vector(b,mode);ha=y<0 or (y==0 and x<0);hb=v<0 or(v==0 and u<0)
  if ha!=hb:return 1 if ha else -1
  cross=x*v-y*u
  return -1 if cross>0 else 1 if cross<0 else (a>b)-(a<b)
 def equiv(a,b):return any(a==b[i:]+b[:i] for i in range(len(b)))
 variants={mode:{v:sorted(seq,key=cmp_to_key(lambda a,b:cmp(a,b,mode))) for v,seq in orders.items()} for mode in ('vertex','segment')}
 mismatches=[]
 for mode,order in variants.items():
  for v,seq in order.items():
   if not equiv(orders[v],seq):
    swapped={**orders,v:seq}
    mismatches.append({'mode':mode,'vertex':v,'point':vertices[v]['point'],'stored':orders[v],'alternative':seq,'walkCountAfterSingleReplacement':len(walks(swapped)),'directions':[{'dart':d,'angle':math.degrees(math.atan2(*reversed(vector(d,mode))))} for d in seq]})
 # Exact rational arithmetic over the stored floating-point coordinates.
 crossings=[]
 for i,a in enumerate(g['edges']):
  for b in g['edges'][i+1:]:
   p=a['segment']['start'];q=b['segment']['start'];v=vector((a['id'],False),'segment');w=vector((b['id'],False),'segment');delta=(Fraction(q['x'])-Fraction(p['x']),Fraction(q['y'])-Fraction(p['y']))
   cross=lambda a,b:a[0]*b[1]-a[1]*b[0]
   det=cross(v,w)
   if not det:continue
   t=cross(delta,w)/det;u=cross(delta,v)/det
   if 0<t<1 and 0<u<1:
    position={'x':float(Fraction(p['x'])+t*v[0]),'y':float(Fraction(p['y'])+t*v[1])}
    shared=set((a['start_vertex'],a['end_vertex']))&set((b['start_vertex'],b['end_vertex']))
    distances=[math.dist((position['x'],position['y']),(vertices[v]['point']['x'],vertices[v]['point']['y'])) for v in shared]
    crossings.append({'edges':[a['id'],b['id']],'t':float(t),'u':float(u),'position':position,'sharedVertices':sorted(shared),'distanceToShared':distances})
 report={'id':row['id'],'vertices':len(vertices),'edges':len(edges),'storedWalks':len(walks(orders)),'alternativeWalks':{k:len(walks(v)) for k,v in variants.items()},'mismatches':mismatches,'properStoredSegmentCrossings':crossings}
 reports.append(report)
 print(row['id'],'walk counts',report['storedWalks'],report['alternativeWalks'],'ordering differences',len(mismatches),'interior crossings',len(crossings))
(root/'remaining-topology-analysis.json').write_text(json.dumps(reports,indent=2)+'\n')
