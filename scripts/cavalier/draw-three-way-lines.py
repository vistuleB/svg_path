"""Draw native CC01697 replay and recorded Cavalier Preserve output."""
from pathlib import Path
import json
from html import escape
root=Path(__file__).resolve().parents[2];base=root/'scripts/cavalier'
r=json.loads((base/'three-way-lines-preview.json').read_text())[0]
u=next(json.loads(l) for l in (base/'original-offset-topology-upstream.jsonl').read_text().splitlines() if json.loads(l)['id']=='CC01697')
p=['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="650" viewBox="0 0 1000 650">','<rect x="0" y="0" width="1000" height="650" fill="white"/>']
def text(x,y,s,size=16,color='#334155',weight='normal'):
 p.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(s)}</text>')
def line(x1,y1,x2,y2,color,width=2,dash=''):
 p.append(f'<path d="M {x1} {y1} L {x2} {y2}" fill="none" stroke="{color}" stroke-width="{width}"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
def coords(q,cy):return f'{110+q["x"]*50:.10f} {cy-q["y"]*50:.10f}'
def segment(s,cy):
 d='M '+coords(s['start'],cy)
 color='#2563eb'
 if s['type']=='Arc':
  d+=f' A {s["radius"]["x"]*50} {s["radius"]["y"]*50} {-s["x_axis_rotation"]} {int(s["large_arc"])} {int(not s["sweep"])} '+coords(s['end'],cy);color='#d97706'
 else:d+=' L '+coords(s['end'],cy)
 p.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="4" stroke-linecap="round"/>')
text(24,32,'Repeated straight-line source: retained round retraces',24,weight='bold')
text(24,59,'CC01697 · round joins · offset magnitude 1 · native replay and Cavalier Preserve output',15)
for top,height in [(78,102),(195,220),(433,174)]:p.append(f'<rect x="20" y="{top}" width="960" height="{height}" rx="8" fill="#f8fafc" stroke="#dbe3ec"/>')
text(38,104,'Source',18,weight='bold');line(110,128,860,128,'#64748b',3)
for x in [0,5,10,15]:
 p.append(f'<circle cx="{110+x*50}" cy="128" r="4" fill="#64748b"/>');text(104+x*50,151,str(x),13)
text(268,171,'Traversal: 0 → 10 → 5 → 10 → 5 → 15',16)
text(38,222,'Our default trimmed output',18,weight='bold');text(674,222,'Traversal length: 35 + 2π ≈ 41.283',15)
cy=290;line(110,cy,860,cy,'#94a3b8',1.5,'5 5')
for walk in r['result']:
 for s in walk['segments']:segment(s,cy)
text(862,cy+5,'source',13,'#64748b')
text(252,384,'Each orange quarter-circle is traversed out and back.',16,'#a65a00')
line(355,363,326,326,'#d97706',1);line(656,363,644,326,'#d97706',1)
text(38,461,'Cavalier: coincident segments preserved',18,weight='bold');text(748,461,'Traversal length: 35',15)
cy=529;line(110,cy,860,cy,'#94a3b8',1.5,'5 5')
for walk in u['paths']:
 for a,b in zip(walk['vertices'],walk['vertices'][1:]):
  assert a[2]==0
  segment({'type':'Line','start':{'x':a[0],'y':a[1]},'end':{'x':b[0],'y':b[1]}},cy)
text(862,cy+5,'source',13,'#64748b')
text(24,636,'Blue spans coincide across outputs; overlapping traversals are drawn in place. Orange is extra native geometry.',15)
p.append('</svg>');out=root/'examples/debug/three-way-lines-trimming.svg';out.write_text('\n'.join(p)+'\n');print(out)
