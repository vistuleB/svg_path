"""Exact binary64-input circle oracle; no third-party dependencies.
Run probe-semicircle.mjs first. Decimal.from_float preserves API input bits.
"""
import json
from decimal import Decimal as D, getcontext
from pathlib import Path
getcontext().prec = 80
base = Path(__file__).parent
rows = []
for c in json.loads((base / 'semicircle-native.json').read_text()):
    x, y = map(D.from_float, c['start'])
    u, v = map(D.from_float, c['end'])
    r = D.from_float(c['radius'])
    dx, dy = (x-u)/2, (y-v)/2
    h2 = dx*dx + dy*dy
    gap = r*r-h2
    corrected = max(r, h2.sqrt())
    coefficient = (max(D(0), gap)/h2).sqrt()
    sign = 1 if c['bulge'] > 0 else -1
    cx, cy = (x+u)/2 + sign*coefficient*dy, (y+v)/2-sign*coefficient*dx
    ax, ay = (D.from_float(c['actual']['center'][k]) for k in ('x','y'))
    # Bulge center independently, before conversion to an SVG radius.
    b = D.from_float(c['bulge'])
    factor = (1-b)*(1+b)/(4*b)
    bx, by = (x+u)/2-(v-y)*factor, (y+v)/2+(u-x)*factor
    rows.append(dict(id=c['id'], exact_radius_squared_minus_half_chord_squared=str(gap),
        svg_center=[str(cx),str(cy)], bulge_center=[str(bx),str(by)],
        native_center_error=[str(ax-cx),str(ay-cy)],
        native_center_error_norm=str(((ax-cx)**2+(ay-cy)**2).sqrt()),
        corrected_radius=str(corrected)))
print(json.dumps(rows, indent=2))
