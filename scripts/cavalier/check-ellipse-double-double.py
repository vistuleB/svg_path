"""Compare the JS double-double experiment with an independent Decimal oracle."""
from pathlib import Path
from decimal import Decimal as D,localcontext
import importlib.util,json,statistics
root=Path(__file__).parent
spec=importlib.util.spec_from_file_location('oracle',root/'check-ellipse-rotation.py');oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
source=json.loads((root/'ellipse-double-double-results.json').read_text())
def evaluate(precision):
 out=[]
 with localcontext() as ctx:
  ctx.prec=precision
  for row in source['rows']:
   a=row['input'];expected,midpoint=oracle.center({'input':a})
   rx=D(a['radius']['x']);ry=D(a['radius']['y']);s,c=oracle.sincos(D(a['x_axis_rotation']))
   dx=(D(a['start']['x'])-D(a['end']['x']))/2;dy=(D(a['start']['y'])-D(a['end']['y']))/2
   x=c*dx+s*dy;y=-s*dx+c*dy
   factor=max(D(1),x*x/(rx*rx)+y*y/(ry*ry)).sqrt();radii=[rx*factor,ry*factor]
   def error(record):return sum((D(record['center'][k])-v)**2 for k,v in zip(['x','y'],expected)).sqrt()
   candidate=row['candidate'];native=row['actual']
   out.append(dict(family=row['family'],expected=[str(v) for v in expected],native_error=str(error(native)),candidate_error=str(error(candidate)),candidate_radius_error=str(max(abs(D(candidate['radius'][k])-v) for k,v in zip(['x','y'],radii))),midpoint=midpoint,candidate_midpoint=candidate['radius_enlarged']))
 return out
rows=evaluate(80);check=evaluate(90)
assert all(abs(D(x)-D(y))<D('1e-58') for a,b in zip(rows,check) for x,y in zip(a['expected'],b['expected']))
summary={}
for family in ['audit','control']:
 selected=[r for r in rows if r['family']==family]
 summary[family]={'cases':len(selected),'native_max_error':max(float(r['native_error']) for r in selected),'candidate_max_error':max(float(r['candidate_error']) for r in selected),'candidate_max_radius_error':max(float(r['candidate_radius_error']) for r in selected),'midpoint_decision_mismatches':sum(r['midpoint']!=r['candidate_midpoint'] for r in selected),'improved':sum(D(r['candidate_error'])<D(r['native_error']) for r in selected),'equal':sum(D(r['candidate_error'])==D(r['native_error']) for r in selected),'worse':sum(D(r['candidate_error'])>D(r['native_error']) for r in selected)}
summary['median_ns_per_call']={k:statistics.median(t[k]/t['calls']*1e6 for t in source['timings']) for k in ['experimentMs','nativeMs']}
print(json.dumps({'summary':summary,'rows':rows},indent=2))
