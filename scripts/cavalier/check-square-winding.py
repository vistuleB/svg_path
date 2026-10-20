"""Independent sampled winding check using known square corner centers.
No native curve evaluation, intersection, or winding code is used.
"""
import math,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
rows=[]
for d in [.5,1.25,1.5,2,2.5]:
    points=[(-1,d-1),(1,d-1)]
    for cx,cy,angle,nxt in [(1,-1,90,(1-d,1)),(1,1,180,(-1,1-d)),(-1,1,270,(d-1,-1)),(-1,-1,0,(-1,d-1))]:
        points.extend((cx+d*math.cos(math.radians(angle+i*90/1000)),cy+d*math.sin(math.radians(angle+i*90/1000))) for i in range(1,1001))
        points.append(nxt)
    angle=sum(math.atan2(a[0]*b[1]-a[1]*b[0],a[0]*b[0]+a[1]*b[1]) for a,b in zip(points,points[1:]+points[:1]))
    winding=angle/(2*math.pi)
    rows.append(dict(distance=d,raw_center_winding=winding,band_center_winding=1-round(winding)))
print(json.dumps(rows,indent=2))
# Preview current public outputs and raw construction, without raster conversion.
records=json.loads((root/'scripts/cavalier/offset-collapse-current.json').read_text())
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="330" viewBox="0 0 1120 330">','<rect x="0" y="0" width="1120" height="330" fill="white"/>']
for i,d in enumerate([.5,1,1.5,2]):
    svg.append(f'<text x="{140+280*i}" y="25" text-anchor="middle" font-family="sans-serif" font-size="18">Inward distance {d}</text>')
    svg.append(f'<g transform="translate({140+280*i} 158) scale(85)">')
    svg.append('<path d="M -1 -1 H 1 V 1 H -1 Z" fill="none" stroke="#94a3b8" stroke-width="0.015"/>')
    for mode,color,width in [('none','#e2a665',.016),('default','#164eae',.04)]:
        r=next(x for x in records if x['name']=='square_collapsed' and x['distance']==d and x['mode']==mode)
        for s in r['result']['subpaths']:
            svg.append(f'<path d="{s["svg"]}" fill="none" stroke="{color}" stroke-width="{width}"/>')
    svg.append('</g>')
svg.append('<text x="560" y="307" text-anchor="middle" font-family="sans-serif" font-size="15">Gray: source square · Orange: raw offset · Blue: default trimmed output</text></svg>')
(root/'examples/debug/square-collapse-winding.svg').write_text('\n'.join(svg))
