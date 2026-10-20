"""Independent 80-digit circle-center check of the exact binary float inputs."""
import decimal
import json
from pathlib import Path

root = Path(__file__).resolve().parent
decimal.getcontext().prec = 80
D = decimal.Decimal.from_float
rows = []
for line in (root / 'offset-semicircle-residual.jsonl').read_text().splitlines():
    case = json.loads(line)
    for i, arc in enumerate(case['rows'][0]['inputArcs']):
        s = arc['segment']
        dx = D(s['end']['x']) - D(s['start']['x'])
        dy = D(s['end']['y']) - D(s['start']['y'])
        r = D(s['radius']['x'])
        h2 = r * r - (dx * dx + dy * dy) / 4
        rows.append(dict(
            id=case['id'], arc=i, exactFloatRadius=str(r),
            radiusSquaredMinusHalfChordSquared=str(h2),
            centerHeight=str(max(h2, decimal.Decimal(0)).sqrt()),
            nativeMidpointCenterDistance=arc['midpointCenterDistance']))
print(json.dumps(rows, indent=2))
