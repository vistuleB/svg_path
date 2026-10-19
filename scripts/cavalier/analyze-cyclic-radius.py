"""High-precision radial checks on stored CC01189 edge geometry (not original SVG)."""
from pathlib import Path
from decimal import Decimal as D, getcontext
import json
getcontext().prec=70
root=Path(__file__).resolve().parent
row=next(r for r in json.loads((root/'cyclic-CC01189-circle-failures.json').read_text()) if r['id']==11)
v=row['vertex']
def p(x): return tuple(D(x[k])-D(v[k]) for k in ['x','y'])
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a): return dot(a,a).sqrt()
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def perp(a): return (-a[1],a[0])
arc=next(e for e in row['incident'] if e['id']==10)['segment']
# Edge 10 is incident at its end; orient it outward.
a,b=p(arc['end']),p(arc['start'])
d=sub(b,a);length=norm(d);radius=D(arc['radius']['x']);sign=D(-1)
h=(radius*radius-length*length/4).sqrt()
c=tuple((x+y)/2+sign*z*h/length for x,y,z in zip(a,b,perp(d)))
# Squared radial derivative has the sign of dot(p, oriented tangent).
# Both signs are positive. On this minor arc (chord/radius < 1e-7),
# a sinusoidal radial derivative cannot have two zeros, so distance increases.
tangent_dots=[sign*dot(x,perp(sub(x,c))) for x in [a,b]]
assert all(x>0 for x in tangent_dots)
assert length/radius < D('1e-7')
cubic=next(e for e in row['incident'] if e['id']==14)['segment']
upper=max(norm(p(cubic[k])) for k in ['start','control1','control2','end'])
lower=norm(a)
assert lower>upper
print(json.dumps({'arc_10_minimum_radius':str(lower),
 'arc_10_endpoint_radial_tangent_dots':[str(x) for x in tangent_dots],
 'arc_10_chord_over_radius':str(length/radius),
 'cubic_14_control_hull_radius_upper_bound':str(upper),
 'separation':str(lower-upper),
 'conclusion':'No circle centered at the stored vertex can intersect both incident segments.'},indent=2))
