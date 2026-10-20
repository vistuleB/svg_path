"""Summarize diagnostics without turning numerical evidence into exact parity."""
from pathlib import Path
import json,collections
root=Path(__file__).resolve().parent
rows=[json.loads(l) for l in (root/'boolean-decomposition-current.jsonl').read_text().splitlines()]
assert len(rows)==56 and len({r['id'] for r in rows})==56
assert all('checked' in r for r in rows)
groups=collections.defaultdict(list)
for r in rows:groups[r['test']].append(r)
summary=[]
for name,rs in groups.items():
 area_errors=[];perimeter_errors=[]
 for r in rs:
  expected=sum(abs(p['area']) for p in r['upstreamProperties'][:r['upstreamPositive']])-sum(abs(p['area']) for p in r['upstreamProperties'][r['upstreamPositive']:])
  area_errors.append(abs(sum(p['area'] for p in r['decomposedCycles'])-expected))
  perimeter_errors.append(abs(sum(p['length'] for p in r['decomposedCycles'])-sum(p['length'] for p in r['upstreamProperties'])))
 summary.append({'test':name,'ids':[r['id'] for r in rs],'scanlines':sum(r['checked'] for r in rs),'maxAreaDifference':max(area_errors),'maxPerimeterDifference':max(perimeter_errors),'maxHorizontalDifference':max(r['maxSymmetricDifferenceWidth'] for r in rs),'maxSampledWitnessClearance':max(r['maxWitnessClearance'] for r in rs),'contourCounts':sorted({(r['contours'],len(r['decomposedCycles']),r['upstreamPositive'],r['upstreamNegative']) for r in rs})})
(root/'boolean-decomposition-summary.json').write_text(json.dumps({'cases':len(rows),'families':summary,'scanlines':sum(r['checked'] for r in rows),'skippedNarrowSampleLevels':sum(r['skippedNarrowStrips'] for r in rows)},indent=2)+'\n')
print(f'{len(rows)} cases, {len(summary)} families; {sum(r["checked"] for r in rows)} scanlines')
