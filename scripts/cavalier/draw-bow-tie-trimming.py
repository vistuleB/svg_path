"""Draw recorded CC01738 geometry; no geometry is recomputed or inferred."""
import json, math
from pathlib import Path
from html import escape
root = Path(__file__).resolve().parents[2]
base = root / 'scripts/cavalier'
raw = json.loads((base/'original-topology-crossing-untrimmed.json').read_text())[0]
trimmed = json.loads((base/'original-topology-crossing-default.json').read_text())[0]
upstream = next(json.loads(l) for l in (base/'original-offset-topology-upstream.jsonl').read_text().splitlines() if json.loads(l)['id']=='CC01738')
def xy(p): return f'{p["x"]:.14g} {p["y"]:.14g}'
def path(segments):
    d='M '+xy(segments[0]['start'])
    for s in segments:
        if s['type']=='Line': d+=' L '+xy(s['end'])
        elif s['type']=='Arc': d+=f' A {xy(s["radius"])} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} '+xy(s['end'])
        else: raise ValueError(s['type'])
    return d

def bulge_path(p):
    v=p['vertices']; d=f'M {v[0][0]} {v[0][1]}'
    for i in range(len(v) if p['closed'] else len(v)-1):
        x,y,b=v[i]; X,Y,_=v[(i+1)%len(v)]
        if b==0: d+=f' L {X} {Y}'
        else:
            r=math.hypot(X-x,Y-y)*(1+b*b)/(4*abs(b))
            d+=f' A {r} {r} 0 {int(abs(b)>1)} {int(b>0)} {X} {Y}'
    return d+(' Z' if p['closed'] else '')
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="470" viewBox="0 0 1280 470">','<rect x="0" y="0" width="1280" height="470" fill="white"/>']
def text(x,y,s,size=15,color='#334155',weight='normal'):
    parts.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(s)}</text>')
text(20,30,'Bow-tie offset: the lower open component disappears during trimming',23,weight='bold')
text(20,56,'CC01738 · signed offset +0.1 · round joins · recorded audit outputs · y increases upward',15)
source=path(raw['normalization'][0])+' Z'
for i,title in enumerate(['1. Source','2. Our untrimmed offset','3. Our default result','4. Cavalier result']):
    x=16+316*i
    parts.append(f'<rect x="{x}" y="78" width="300" height="350" rx="8" fill="#f8fafc" stroke="#dbe3ec"/>')
    text(x+14,105,title,18,weight='bold')
    parts.append(f'<g transform="translate({x+34} 373) scale(58 -58)" fill="none" stroke-linejoin="round" stroke-linecap="round">')
    parts.append(f'<path d="{source}" stroke="#94a3b8" stroke-width="0.027" stroke-dasharray="0.07 0.07"/>')
    if i==0:
        parts.append(f'<path d="{source}" stroke="#475569" stroke-width="0.045"/>')
        # Arrows show the source traversal, rather than suggesting erosion.
        for s in raw['normalization'][0]:
            a,b=s['start'],s['end'];dx,dy=b['x']-a['x'],b['y']-a['y'];n=math.hypot(dx,dy);ux,uy=dx/n,dy/n
            px,py=a['x']+0.63*dx,a['y']+0.63*dy
            parts.append(f'<path d="M {px-.16*ux+.07*uy} {py-.16*uy-.07*ux} L {px} {py} L {px-.16*ux-.07*uy} {py-.16*uy+.07*ux}" stroke="#475569" stroke-width="0.035"/>')
    if i in [1,2]:
        rows=raw['result'] if i==1 else trimmed['result']
        for r in rows: parts.append(f'<path d="{path(r["segments"])}" stroke="{"#087f8c" if i==1 else "#6d28d9"}" stroke-width="0.045"/>')
    if i==3:
        for p in upstream['paths']:
            color='#6d28d9' if p['closed'] else '#d97706'
            parts.append(f'<path d="{bulge_path(p)}" stroke="{color}" stroke-width="0.045"/>')
            if not p['closed']:
                for q in [p['vertices'][0],p['vertices'][-1]]:
                    parts.append(f'<circle cx="{q[0]}" cy="{q[1]}" r="0.055" fill="{color}" stroke="white" stroke-width="0.018"/>')
    parts.append('</g>')
    text(x+14,408,['Closed, self-crossing path','Both regions present in raw geometry','Only the upper closed triangle','Upper triangle + lower open walk'][i],14)
text(20,453,'Orange: component present in Cavalier but absent from our trimmed output. Dots mark its two open endpoints.',15)
parts.append('</svg>')
out=root/'examples/debug/bow-tie-trimming-comparison.svg';out.write_text('\n'.join(parts)+'\n');print(out)
