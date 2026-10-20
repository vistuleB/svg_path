import json
from pathlib import Path
root=Path(__file__).resolve().parent
read=lambda n:[json.loads(l) for l in (root/n).read_text().splitlines()]
rows=read('original-boolean-scanlines.jsonl');rechecks={(r['id'],r['mode']):r for r in read('original-boolean-orthogonal-rechecks.jsonl')}
effective=[rechecks.get((r['id'],r['mode']),r) for r in rows]
summary={'cases':len({r['id'] for r in rows}),'orthogonal_rechecks':list(map(list,rechecks)),'modes':{},'pairs':[]}
for mode in ['output','stored-edges']:
 a=[r for r in effective if r['mode']==mode];good=[r for r in a if 'checked' in r]
 summary['modes'][mode]={'completed':len(good),'scanlines':sum(r['checked'] for r in good),'maxSampledClearance':max(r['maxWitnessClearance'] for r in good),'maxEndpointAdjustment':max((r.get('preSnap') or {}).get('maxEndpointAdjustment',0) for r in good),'errorIds':[r['id'] for r in a if 'probe_error' in r],'timeoutIds':[r['id'] for r in a if 'timeout_seconds' in r]}
for id in dict.fromkeys(r['id'] for r in rows):
 a={r['mode']:r for r in effective if r['id']==id}
 if all('checked' in r for r in a.values()):summary['pairs'].append({'id':id,'outputClearance':a['output']['maxWitnessClearance'],'storedEdgeClearance':a['stored-edges']['maxWitnessClearance'],'maxEndpointAdjustment':a['stored-edges']['preSnap']['maxEndpointAdjustment']})
(root/'original-boolean-stage-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='pairs'},indent=2))
