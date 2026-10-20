import json,collections
from pathlib import Path
root=Path(__file__).resolve().parent
read=lambda n:[json.loads(l) for l in (root/n).read_text().splitlines()]
props={x['id']:x for x in read('original-offset-topology-results.jsonl')}
rows=read('original-topology-boundary-checks.jsonl')
assert len(rows)==192 and all(x.get('upstreamExportPropertiesMatch') for x in rows)
groups=collections.defaultdict(list)
for x in rows:
 if props[x['id']]['status']=='match':kind='property-match'
 elif x['status']=='sampled-boundary-set-match':kind='contour-grouping' if abs(x['nativeLength']-x['upstreamLength'])<1e-4 else 'traversal-multiplicity'
 elif x['test'].endswith('three_way_coincident_lines'):kind='round-retrace-source-distance-policy'
 elif x['test']=='touching_loop_behavior_does_not_change_crossing_routing':kind='winding-parity-removal'
 elif 'coincident_segment_behavior: Discard' in x['policy']:
  # The same native call must agree with a Preserve boundary comparison.
  assert any(y['nativeId']==x['nativeId'] and 'coincident_segment_behavior: Preserve' in y['policy'] and y['status']=='sampled-boundary-set-match' for y in rows)
  kind='coincident-discard-policy'
 else:raise ValueError(x['id'])
 groups[kind].append(x['id'])
(root/'original-topology-dispositions.json').write_text(json.dumps(dict(groups),indent=2)+'\n')
lines=['| Original family | Records | Property matches | Disposition of flags |','| --- | ---: | ---: | --- |']
for test in dict.fromkeys(x['test'] for x in rows):
 a=[x for x in rows if x['test']==test]; counts=collections.Counter(k for x in a for k,ids in groups.items() if x['id'] in ids)
 lines.append(f"| `{test}` | {len(a)} | {counts.pop('property-match',0)} | "+', '.join(f'{k}: {v}' for k,v in counts.items())+' |')
(root/'original-topology-family-table.md').write_text('\n'.join(lines)+'\n')
print({k:len(v) for k,v in groups.items()})
