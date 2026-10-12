"""Collect all diagnostic outputs, including errors, without weakening references."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/bounds.json').read_text())['fixtures']
report={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 results=[]
 for line in Path(filename).read_text().splitlines():
  m=re.match(r'^(\d+):(.*)$',line)
  if not m:continue
  id=int(m[1]);value=m[2];f=fixtures[id]
  r={'id':id,'block':f['block'],'raw':value,'expected':f['expected']}
  if value.startswith('Ok('):
   actual=json.loads(value[3:-1]);error=max(abs(a-b) for a,b in zip(actual,f['expected']))
   r.update(actual=actual,error=error,tolerance=0.00002,status='match' if error<=0.00002 else 'discrepancy')
  else:r.update(status='library-error')
  results.append(r)
 assert [r['id'] for r in results]==list(range(len(fixtures))),f'{target}: incomplete native run'
 report[target]=results
 print(target,{s:sum(r['status']==s for r in results) for s in ['match','discrepancy','library-error']})
assert len(report)==2
(root/'scripts/paperjs/bounds-native-screening.json').write_text(json.dumps(report,indent=2)+'\n')
