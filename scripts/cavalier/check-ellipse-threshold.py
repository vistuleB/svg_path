"""Independent oracle checks for the proposed dispatch boundary and worst cases."""
from pathlib import Path
from decimal import Decimal as D,localcontext
import importlib.util,json
root=Path(__file__).parent
spec=importlib.util.spec_from_file_location('oracle',root/'check-ellipse-rotation.py');oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
grid=json.loads((root/'ellipse-threshold-grid.json').read_text());rows=grid['rows']
# Every explicit boundary/audit case, worst fast-path errors, and a spaced grid.
indices=set(i for i,r in enumerate(rows) if r['family']!='grid')
indices.update(sorted((i for i,r in enumerate(rows) if r['gap']>1e-8*r['k']**2),key=lambda i:rows[i]['nativeErrorVsDD'] or 0,reverse=True)[:60])
indices.update(range(0,len(rows),47))
def run(precision):
 out=[]
 with localcontext() as ctx:
  ctx.prec=precision
  for i in sorted(indices):
   r=rows[i];expected,midpoint=oracle.center({'input':r['input']});size=D(max(r['input']['radius'].values()))
   def err(a):return sum((D(a['center'][axis])-v)**2 for axis,v in zip(['x','y'],expected)).sqrt()/size
   fallback=r['gap']<=1e-8*r['k']**2
   out.append(dict(index=i,family=r['family'],fallback=fallback,expected=[str(v) for v in expected],native_error=str(err(r['actual'])),candidate_error=str(err(r['candidate'])),hybrid_error=str(err(r['candidate'] if fallback else r['actual'])),candidate_midpoint_matches=r['candidate']['radius_enlarged']==midpoint))
 return out
out=run(80);check=run(90)
assert all(abs(D(x)-D(y))<D('1e-55') for a,b in zip(out,check) for x,y in zip(a['expected'],b['expected']))
summary={'oracle_cases':len(out),'max_hybrid_relative_center_error':max(float(r['hybrid_error']) for r in out),'max_candidate_relative_center_error':max(float(r['candidate_error']) for r in out),'candidate_branch_mismatches':sum(not r['candidate_midpoint_matches'] for r in out)}
print(json.dumps({'summary':summary,'rows':out},indent=2))
