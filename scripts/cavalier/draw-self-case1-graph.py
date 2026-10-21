from pathlib import Path
import json
root=Path(__file__).resolve().parents[2];r=json.loads((root/'scripts/cavalier/self-case1-graph.json').read_text());stage=r[0];graph=stage['args'][0]['graph'];eligible={e['id'] for e in stage['args'][1]['edges']};good={e['id'] for e in stage['result']['0']['edges']}
def xy(p):return f'{p["x"]:.14g} {p["y"]:.14g}'
def path(s):
 d='M '+xy(s['start'])
 if s['type']=='Line':return d+' L '+xy(s['end'])
 assert s['type']=='Arc'
 return d+f' A {xy(s["radius"])} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} '+xy(s['end'])
bs=[e['bounds'] for e in graph['edges']];whole=(min(b['min']['x'] for b in bs),min(b['min']['y'] for b in bs),max(b['max']['x'] for b in bs),max(b['max']['y'] for b in bs))
out=['<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="680" viewBox="0 0 1320 680">','<rect x="0" y="0" width="1320" height="680" fill="white"/>']
def text(x,y,t,size=17,col='#334155'):out.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{col}">{t}</text>')
text(20,32,'Self-intersecting case 1 — arrangement before winding deletion or parity pruning',23)
text(20,63,'Green: winding-compatible offset edges · Red: submerged offset edges · Gray dashed: other arrangement edges')
for i,(box,x,w,title) in enumerate([(whole,15,720,'Full arrangement'),((235,95,325,185),750,555,'Detail near the crossing and open ends')]):
 text(x+10,100,title,20);xmin,ymin,xmax,ymax=box;sc=min((w-45)/(xmax-xmin),440/(ymax-ymin));cx=x+w/2;cy=350;mx=(xmin+xmax)/2;my=(ymin+ymax)/2
 out.append(f'<defs><clipPath id="p{i}"><rect x="{x}" y="120" width="{w}" height="465"/></clipPath></defs><g clip-path="url(#p{i})"><g transform="translate({cx} {cy}) scale({sc} {-sc}) translate({-mx} {-my})">')
 for e in sorted(graph['edges'],key=lambda e:e['id'] in eligible):
  id=e['id'];color='#15803d' if id in good else '#dc2626' if id in eligible else '#a8b0bd';stroke=3 if id in eligible else 1.4;dash='' if id in eligible else f' stroke-dasharray="{4/sc} {3/sc}"'
  out.append(f'<path d="{path(e["segment"])}" fill="none" stroke="{color}" stroke-width="{stroke/sc}"{dash}/>')
 for v in graph['vertices']:
  p=v['point'];out.append(f'<circle cx="{p["x"]}" cy="{p["y"]}" r="{2.5/sc}" fill="#334155"/>')
 out.append('</g></g>')
 if i==1:
  for v in graph['vertices']:
   p=v['point'];X=cx+(p['x']-mx)*sc;Y=cy-(p['y']-my)*sc
   if x+10<X<x+w-30 and 135<Y<570:text(X+5,Y-5,str(v['id']),12)
text(20,617,'60 arrangement edges: 29 offset-image edges = 16 winding-compatible + 13 submerged.')
text(20,648,'All red edges are still shown here. Subsequent winding deletion and parity pruning leave only 2 offset edges.')
out.append('</svg>');p=root/'examples/debug/self-case1-arrangement-pre-trimming.svg';p.write_text('\n'.join(out)+'\n');print(p)
