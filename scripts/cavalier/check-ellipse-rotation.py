"""80-digit exact-input center oracle; separate rounded-trig diagnostic.
Taylor sine/cosine on a reduced angle; no third-party numerical dependency.
"""
from decimal import Decimal as D,localcontext
from pathlib import Path
import json
PI=D('3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679')
def sincos(degrees):
    x=degrees*PI/D(180)
    sine=st=x; cosine=ct=D(1)
    for n in range(1,150):
        st *= -x*x/D((2*n)*(2*n+1)); ct *= -x*x/D((2*n-1)*(2*n))
        sine+=st;cosine+=ct
    return sine,cosine

def center(row,rounded_trig=False):
    a=row['input'];p=a['start'];q=a['end']
    rx=D(a['radius']['x']);ry=D(a['radius']['y'])
    dx=(D(p['x'])-D(q['x']))/2;dy=(D(p['y'])-D(q['y']))/2
    s,c=(D(row['sin']),D(row['cos'])) if rounded_trig else sincos(D(a['x_axis_rotation']))
    x=c*dx+s*dy;y=-s*dx+c*dy
    gap=rx*rx*ry*ry-rx*rx*y*y-ry*ry*x*x
    if gap<=0:k=D(0)
    else:k=(gap/(rx*rx*y*y+ry*ry*x*x)).sqrt()
    if a['large_arc']==a['sweep']:k=-k
    cx=k*rx*y/ry;cy=-k*ry*x/rx
    return [(D(p['x'])+D(q['x']))/2+c*cx-s*cy,(D(p['y'])+D(q['y']))/2+s*cx+c*cy],gap<=0

def run(precision):
    rows=[]
    with localcontext() as ctx:
        ctx.prec=precision
        for r in json.loads((Path(__file__).parent/'ellipse-rotation-inputs.json').read_text()):
            expected,enlarged=center(r);rounded,_=center(r,True)
            actual=[D(r['actual']['center'][axis]) for axis in ['x','y']]
            distance=lambda a,b:sum((x-y)**2 for x,y in zip(a,b)).sqrt()
            rows.append(dict(ratio=r['ratio'],rotation=r['rotation'],shift=r['shift'],radius_enlarged=enlarged,expected=[str(x) for x in expected],actual_error=str(distance(actual,expected)),rounded_trig_high_precision_error=str(distance(rounded,expected))))
    return rows
if __name__=='__main__':
    a=run(80);b=run(90)
    # Oracle convergence check is far tighter than the binary64 discrepancies.
    assert all(abs(D(x)-D(y))<D('1e-60') for r,t in zip(a,b) for x,y in zip(r['expected'],t['expected']))
    print(json.dumps(a,indent=2))
