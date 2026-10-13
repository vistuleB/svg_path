"""Compare saved address/classification results with the pinned assertions."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent
raw=json.loads((root/'intersection-address-findings.json').read_text())
rows=[]
for f in raw['results']:
 for ordinal,e in enumerate(f['expected']):
  matches=[]
  for h in f['hits']:
   if max(abs(h['point'][axis]-e['point'][i]) for i,axis in enumerate(['x','y']))>1e-5:continue
   for p in h['pairs']:
    a=p['left']
    if 'index' in e and a['segment_index']!=e['index']:continue
    if 'time' in e:
     if e['time'] in [0,1] and a['t']!=e['time']:continue
     if abs(a['t']-e['time'])>5.1e-6:continue
    matches.append(p)
  classes=sorted(set(p['classification']['0']['type'] for p in matches))
  row={'fixture':f['id'],'expectation':ordinal,'upstream':e,'matchedAddresses':len(matches),'classifications':classes}
  if not matches:
   row['status']='understood-absent-near-contact' if (f['id'],ordinal)==(18,0) else 'unresolved-missing'
  elif 'crossing' not in e:
   row['status']='address-match-no-upstream-crossing-assertion'
  elif all((c=='Crossing')==e['crossing'] and c in ['Crossing','Touching','EndpointContact'] for c in classes):
   row['status']='address-and-crossing-match'
  elif f['id']==12 and ordinal in [0,1] and classes==['Touching']:
   row['status']='understood-overlap-boundary-classification'
  else:row['status']='unresolved-classification'
  rows.append(row)
from collections import Counter
pairs=[p for f in raw['results'] for h in f['hits'] for p in h['pairs']]
report={'fixtures':len(raw['results']),'returnedParameterPairs':len(pairs),
 'maximumPairSeparation':max(p['separation'] for p in pairs),
 'maximumPointResidual':max(max(p['leftPointResidual'],p['rightPointResidual']) for p in pairs),
 'counts':dict(Counter(r['status'] for r in rows)),'comparisons':rows}
assert all(p['separation']<=raw['tolerance'] and p['leftPointResidual']<=raw['tolerance'] and p['rightPointResidual']<=raw['tolerance'] for p in pairs)
assert not any(r['status'].startswith('unresolved') for r in rows)
(root/'intersection-address-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='comparisons'},indent=2))
