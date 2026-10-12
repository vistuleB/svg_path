import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
f=next(x for x in json.loads((root/'scripts/paperjs/segments.json').read_text())['fixtures'] if x['beforeReverse'])
node=json.loads(re.sub(r'(\w+):',r'"\1":',f['expected']))
expected=[node[key][axis] for key in ['point','handleIn','handleOut'] for axis in ['x','y']]
report={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 lines=Path(filename).read_text().splitlines();matches=[x for x in lines if x.startswith('10:')];assert len(matches)==1
 actual=json.loads(matches[0].split(':',1)[1]);checks={k:next(x for x in lines if x.startswith(k+':')).split(':',1)[1]=='True' for k in ['closed','continuous','double_reverse']}
 report[target]={'fixtureId':f['id'],'expected':expected,'actual':actual,'status':'match' if actual==expected and all(checks.values()) else 'discrepancy','supplementaryChecks':checks}
 print(target,report[target])
assert len(report)==2
(root/'scripts/paperjs/segments-native-screening.json').write_text(json.dumps(report,indent=2)+'\n')
