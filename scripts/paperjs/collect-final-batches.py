import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];base=root/'scripts/paperjs'
num=json.loads((base/'numerical.json').read_text())['fixtures'];comp=json.loads((base/'compound-paths.json').read_text())['fixtures'];reports={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 results=[]
 for line in Path(filename).read_text().splitlines():
  m=re.match(r'^(numerical|compound)-(\d+):(.*)$',line)
  if not m:continue
  kind,id,raw=m[1],int(m[2]),m[3];f=(num if kind=='numerical' else comp)[id];r={'kind':kind,'id':id,'raw':raw,'expected':f['expected']}
  if kind=='numerical':
   if not raw.startswith('Ok('):r['status']='library-error'
   else:
    actual=json.loads(raw[3:-1]);a,b=sorted(actual),sorted(f['expected']);error=max(abs(x-y) for x,y in zip(a,b)) if len(a)==len(b) else None
    residuals=[]
    for x in actual:
     value=0;scale=max(abs(c) for c in f['coefficients'])
     for c in f['coefficients']:value=value*x+c/scale
     residuals.append(abs(value))
    r.update(actual=actual,rootOrderDiffers=actual!=f['expected'] and a==b,maxRootError=error,tolerance=1e-9,normalizedPolynomialResiduals=residuals,status='match' if error is not None and error<=1e-9 else 'discrepancy')
  else:
   actual=True if raw=='True' else False if raw=='False' else int(raw) if raw.isdigit() else raw
   r.update(actual=actual,status='match' if actual==f['expected'] else 'discrepancy')
  results.append(r)
 assert [(r['kind'],r['id']) for r in results]==[(kind,i) for kind in ['numerical','compound'] for i in range(4)]
 reports[target]=results;print(target, sum(r['status']=='match' for r in results),'of',len(results),'matches')
assert len(reports)==2
(base/'final-batches-native-screening.json').write_text(json.dumps(reports,indent=2)+'\n')
