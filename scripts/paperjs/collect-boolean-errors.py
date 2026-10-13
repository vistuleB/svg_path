"""Collect diagnostic evidence, checking that both targets cover the same 69 cases.
Usage: python3 scripts/paperjs/collect-boolean-errors.py JS_REPORT TOPOLOGY_REPORT ERLANG_LOG
Run check-overlap-witnesses.py and check-crossing-witnesses.py first.
"""
from pathlib import Path
import collections, hashlib, json, math, re, sys
root = Path(__file__).resolve().parents[2]
audit = root / 'scripts/paperjs'
raw = json.loads(Path(sys.argv[1]).read_text())['results']
topology = {r['id']: r for r in json.loads(Path(sys.argv[2]).read_text())}
erlang = {int(i): text for i, text in re.findall(r'Fixture (\d+)\n([^\n]+)', Path(sys.argv[3]).read_text())}
assert len(raw) == len(erlang) == 69
assert {r['id'] for r in raw} == set(erlang)
overlaps = {r['id']: r for r in json.loads((audit/'boolean-overlap-witnesses.json').read_text())}
crossings = {r['id']: r for r in json.loads((audit/'boolean-crossing-witnesses.json').read_text())}
assert len(overlaps) == 55 and all(r['witness']['certified'] for r in overlaps.values())
assert len(crossings) == 8 and all(not r['rootInsideWindow'] for r in crossings.values())
rows = []
for r in raw:
    id = r['id']
    error = r['result']['0']
    terminal = error
    while 'error' in terminal:
        terminal = terminal['error']
    assert terminal['type'] in erlang[id], (id, terminal, erlang[id])
    if terminal['type'] == 'CrossingMaxIterationsReached':
        match = re.search(r'CrossingMaxIterationsReached\(([^,]+), ([^)]+)\)', erlang[id])
        assert match and [float(match[1]), float(match[2])] == [terminal['estimate'], terminal['value']]
    if error['type'] == 'InternalBoundaryTopologyError':
        assert f"InternalBoundaryTopologyError({error['vertex']}, SectorMismatch)" in erlang[id]
    row = dict(id=id, javascript=error, erlang=erlang[id])
    if id in overlaps:
        row.update(status='understood-overlap-contract-limitation', evidence='boolean-overlap-witnesses.json')
    elif id in crossings:
        row.update(status='confirmed-our-failure', cause='crossing-root-isolation', evidence='boolean-crossing-witnesses.json')
    else:
        assert id in [69,79,113,122,123,172]
        row.update(status='confirmed-our-failure', cause={69:'tangent-only-sector-order',172:'tangent-only-sector-order',79:'boundary-side-classification',113:'boundary-side-classification',122:'minimum-size-filter-and-classification',123:'minimum-size-filter-and-classification'}[id])
        vertex=error['vertex']
        row['failingVertex']=next(v for v in r['graph']['vertices'] if v['id']==vertex)
        row['rays']=[x for x in r['trace'] if x['kind']=='rays' and x['vertex']==vertex]
        row['arrangementOrder']=next(x for x in r['graph']['cyclic_orders'] if x[0]==vertex)
        row['closedBoundaryValidation']=topology[id]['validate']
        row['classificationToleranceSweep']=[dict(tolerance=x['tolerance'],imbalance=x['imbalance']) for x in topology[id]['classifications']]
        row['incidentEdges']=[e for e in r['graph']['edges'] if vertex in (e['start_vertex'],e['end_vertex'])]
        if id in [69,172]:
            row['secantOrders']=[]
            for t in [1e-4,1e-3,1e-2]:
                samples=[]
                for ray in row['rays'][0]['ordered']:
                    edge=next(e for e in r['boundary']['0'] if e['id']==ray['edge_id'])
                    controls=[tuple(edge['segment'][k][a] for a in ['x','y']) for k in ['start','control1','control2','end']]
                    if not ray['starts']:controls.reverse()
                    points=controls[:]
                    while len(points)>1:
                        points=[tuple(a*(1-t)+b*t for a,b in zip(x,y)) for x,y in zip(points,points[1:])]
                    angle=math.degrees(math.atan2(points[0][1]-controls[0][1],points[0][0]-controls[0][0]))%360
                    samples.append(dict(edge=ray['edge_id'],starts=ray['starts'],angle=angle))
                samples.sort(key=lambda x:x['angle'])
                assert all(samples[i]['starts'] != samples[(i+1)%len(samples)]['starts'] for i in range(len(samples)))
                row['secantOrders'].append(dict(parameter=t,ordered=samples))
    rows.append(row)
report=dict(date='2026-10-13',scope='Reproduction and cause classification of the 69 saved Boolean errors; no production edits or passing CSG equivalence claim.',
            sourceSha256={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'src').rglob('*.gleam'))},
            totals=dict(collections.Counter(r['status'] for r in rows)),results=rows)
(audit/'boolean-error-findings.json').write_text(json.dumps(report,indent=2)+'\n')
statuses=json.loads((audit/'boolean-status.json').read_text())
for s in statuses:
    if s['id'] not in erlang:continue
    row=next(r for r in rows if r['id']==s['id'])
    s['status']=row['status']
    s['evidence']='Reproduced on Erlang and JavaScript 2026-10-13; see boolean-error-findings.json and BOOLEAN_ERROR_TRIAGE.md. '+(
        'The detected overlap fails the required affine parameter correspondence; this explains the blocker, not all later CSG behavior.' if s['id'] in overlaps else 'Default operation fails; identified mechanism: '+row['cause']+'. No production fix applied.')
(audit/'boolean-status.json').write_text(json.dumps(statuses,indent=2)+'\n')
print(report['totals'])
