"""Explain the endpoint-family perimeter discrepancy using captured raw curves."""
import json,math
from pathlib import Path
root=Path(__file__).resolve().parent
up=json.loads((root/'boolean-endpoints-upstream-geometry.json').read_text())
native={r['id']:r for r in map(json.loads,(root/'boolean-decomposition-current.jsonl').read_text().splitlines())}
def segments(p):
 vs=p['geometry']['vertices']
 return [(tuple(v[:2]),tuple(vs[(i+1)%len(vs)][:2]),v[2]) for i,v in enumerate(vs)]
def length(s):
 a,b,bulge=s;chord=math.dist(a,b)
 return chord if not bulge else chord*(1+bulge*bulge)/abs(bulge)*abs(math.atan(bulge))
rows=[]
for r in up:
 assert len(r['positive'])==2 and not r['negative']
 a,b=map(segments,r['positive']);shared=[]
 for s in a:
  if s in b or (s[1],s[0],-s[2]) in b:shared.append(s)
 shared_length=sum(map(length,shared))
 delta=sum(p['length'] for p in r['positive'])-sum(p['length'] for p in native[r['id']]['decomposedCycles'])
 rows.append({'id':r['id'],'shared_segments':shared,'shared_length':shared_length,'upstream_perimeter_excess':delta,'residual_after_removing_double_count':delta-2*shared_length})
 assert abs(delta-2*shared_length)<1e-8
(root/'boolean-endpoints-shared-boundaries.json').write_text(json.dumps(rows,indent=2)+'\n')
print([(r['id'],r['shared_length'],r['residual_after_removing_double_count']) for r in rows])
