import json
import re
from decimal import Decimal as D, getcontext
from pathlib import Path

getcontext().prec = 90
base = Path(__file__).resolve().parent
fixture = json.loads((base / 'almost-collinear-fixture.json').read_text())

def evaluate(points, t, scale):
    points = [[D.from_float(float(p[0])), D.from_float(float(p[1])) * scale] for p in points]
    while len(points) > 1:
        points = [[(1-t)*a+t*b for a,b in zip(p,q)] for p,q in zip(points,points[1:])]
    return points[0]

def distance(a, b):
    return sum((x-y)**2 for x,y in zip(a,b)).sqrt()

rows = []
pattern = r'SegmentIntersection\((?:left_t: )?([\d.e+-]+), (?:right_t: )?([\d.e+-]+), (?:point: )?Point\((?:x: )?([\d.e+-]+), (?:y: )?([\d.e+-]+)\)\)'
for target in ['javascript', 'erlang']:
    for line in (base / f'almost-collinear-{target}.log').read_text().splitlines():
        if line.startswith('Y SCALE '):
            scale = int(line.split()[-1])
        if line.startswith('TOL '):
            tolerance = float(line.split()[-1])
            reverse = False
        if not line.startswith('points '):
            continue
        pairs = re.findall(pattern, line)
        checks = []
        for t,u,x,y in pairs:
            a = evaluate(fixture['right' if reverse else 'left'], D.from_float(float(t)), D(scale))
            b = evaluate(fixture['left' if reverse else 'right'], D.from_float(float(u)), D(scale))
            p = [D.from_float(float(x)), D.from_float(float(y))]
            checks.append(float(max(distance(a,p), distance(b,p))))
        status = line.split('Error(')[1].split('(')[0].split(')')[0] if 'Error(' in line else 'ok'
        assert status != 'ok' or pairs, 'Unparsed successful result'
        rows.append(dict(target=target, y_scale=scale, tolerance=tolerance, reversed=reverse, status=status, count=len(pairs), max_high_precision_point_residual=max(checks, default=None)))
        reverse = not reverse
assert [(r['status'],r['count']) for r in rows[:16]] == [(r['status'],r['count']) for r in rows[16:]]
(base / 'almost-collinear-analysis.json').write_text(json.dumps(rows, indent=2)+'\n')
for r in rows[:16]:
    print(r)
