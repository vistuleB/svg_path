"""Compare native geometry to the source test's expected string coordinates."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/constructors.json').read_text())['fixtures']
def expected_curves(f):
 nodes=json.loads('['+re.sub(r'(\w+):',r'"\1":',f['expected'])+']')
 curves=[]
 for i in range(len(nodes) if f['closed'] else len(nodes)-1):
  a,b=nodes[i],nodes[(i+1)%len(nodes)];p=a['point'];q=b['point'];u=a.get('handleOut',{'x':0,'y':0});v=b.get('handleIn',{'x':0,'y':0})
  curves.append([p['x'],p['y'],p['x']+u['x'],p['y']+u['y'],q['x']+v['x'],q['y']+v['y'],q['x'],q['y']])
 return curves
# A duplicated endpoint with zero handles contributes no geometry. This occurs
# explicitly in the oversized rounded-rectangle reference and in our SVG path.
def drop_empty(curves):return [c for c in curves if not all(c[i:i+2]==c[:2] for i in [2,4,6])]
def compare(a,b,closed):
 a,b=drop_empty(a),drop_empty(b)
 if len(a)!=len(b):return None
 shifts=range(len(a)) if closed else [0]
 return min(max(abs(x-y) for i,c in enumerate(a) for x,y in zip(c,b[(i+j)%len(b)])) for j in shifts)
report={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 out=[]
 for line in Path(filename).read_text().splitlines():
  m=re.match(r'^(\d+):(.*)$',line)
  if not m:continue
  id=int(m[1]);raw=m[2];f=fixtures[id];r={'id':id,'block':f['block'],'raw':raw}
  if not raw.startswith('Ok('):r['status']='library-error'
  else:
   rows=json.loads(raw[3:-1]);closed=rows[0]==[1];delta=compare(rows[1:],expected_curves(f),closed)
   r.update(closed=closed,expectedClosed=f['closed'],maxCoordinateError=delta,tolerance=0.00002,status='match' if closed==f['closed'] and delta is not None and delta<=0.00002 else 'discrepancy')
  out.append(r)
 assert [r['id'] for r in out]==[0,1,2,3,5,6,7,8,19,20]
 report[target]=out
 print(target,[(r['id'],r['status'],r.get('maxCoordinateError')) for r in out])
assert len(report)==2
(root/'scripts/paperjs/constructors-native-screening.json').write_text(json.dumps(report,indent=2)+'\n')
