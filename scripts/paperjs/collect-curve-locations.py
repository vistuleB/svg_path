import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/curve-locations.json').read_text())['fixtures'];report={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 results=[]
 for line in Path(filename).read_text().splitlines():
  m=re.match(r'^(cubic|lines)-(\d+):(.*)$',line)
  if not m:continue
  mode,id,raw=m[1],int(m[2]),m[3];f=fixtures[id];point=f['points'][f['nodeIndex']];expected=[f['expected'],*point,*point]
  r={'id':id,'representation':mode,'expected':expected,'raw':raw}
  if raw.startswith('Ok('):
   actual=json.loads(raw[3:-1]);r.update(actual=actual,status='match' if actual==expected else 'discrepancy')
  else:r['status']='library-error'
  results.append(r)
 assert [(x['representation'],x['id']) for x in results]==[(mode,i) for mode in ['cubic','lines'] for i in range(4)]
 report[target]=results
 print(target, sum(r['status']=='match' for r in results),'of',len(results),'exact matches')
assert len(report)==2
(root/'scripts/paperjs/curve-locations-native-screening.json').write_text(json.dumps(report,indent=2)+'\n')
