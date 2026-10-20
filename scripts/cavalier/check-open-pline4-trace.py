"""Check graph connectivity and independently sampled winding-pair agreement."""
import json
from collections import Counter
from pathlib import Path
root = Path(__file__).resolve().parent
rows = json.loads((root / 'offset-post-reversal-CC01287-trace.json').read_text())
graph = next(r for r in rows if r['stage'] == 'delete_winding_mismatched_edges')['result']['0']
protected = next(r for r in rows if r['stage'] == 'forced_parity_reduce_trim_graph')['protected']
vertices = {v['id']: v['point'] for v in graph['vertices']}
pending = {e['id']: e for e in graph['edges']}
components = []
while pending:
    reached = {next(iter(pending.values()))['start_vertex']}
    edges = []
    while True:
        found = [e for e in pending.values() if e['start_vertex'] in reached or e['end_vertex'] in reached]
        if not found:
            break
        for edge in found:
            edges.append(edge)
            reached.update([edge['start_vertex'], edge['end_vertex']])
            del pending[edge['id']]
    degrees = Counter(v for e in edges for v in [e['start_vertex'], e['end_vertex']])
    components.append({'edges': [e['id'] for e in edges], 'terminals': [
        {'id': v, 'point': vertices[v], 'protected': v in protected}
        for v, d in degrees.items() if d == 1], 'degrees': dict(degrees)})
(root / 'offset-post-reversal-CC01287-components.json').write_text(json.dumps(components, indent=2) + '\n')
samples = json.loads((root / 'offset-post-reversal-CC01287-winding-samples.json').read_text())
for row in samples:
    for sample in row['samples']:
        assert all(v['type'] == 'Ok' and v['0']['type'] == 'Winding' for v in sample['pair'])
        # Algebraic left normal versus the library's visual-left convention.
        pair = [v['0']['0'] for v in sample['pair']][::-1]
        assert pair == row['measured'], (row['edge'], sample)
assert len(samples) == 30
assert len(components) == 7
assert all(len(c['terminals']) == 2 and not all(t['protected'] for t in c['terminals']) for c in components)
print('30 edge pairs agree at three distances; seven open chains each have an unprotected terminal.')
