from pathlib import Path
import json,math
from html import escape
root=Path(__file__).resolve().parents[2];base=root/'scripts/cavalier'
up={r['id']:r for r in map(json.loads,(base/'original-offset-specific-upstream.jsonl').read_text().splitlines())}
def xy(p):return f'{p["x"]:.14g} {p["y"]:.14g}'
def native(ss):
 d='M '+xy(ss[0]['start'])
 for s in ss:
  if s['type']=='Line':d+=' L '+xy(s['end'])
  elif s['type']=='Arc':d+=f' A {xy(s["radius"])} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} '+xy(s['end'])
  else:raise ValueError(s['type'])
 return d

def bulge(p):
 v=p['vertices'];d=f'M {v[0][0]} {v[0][1]}'
 for i in range(len(v) if p['closed'] else len(v)-1):
  x,y,b=v[i];X,Y,_=v[(i+1)%len(v)]
  if b==0:d+=f' L {X} {Y}'
  else:
   r=math.hypot(X-x,Y-y)*(1+b*b)/(4*abs(b));d+=f' A {r} {r} 0 {int(abs(b)>1)} {int(b>0)} {X} {Y}'
 return d+(' Z' if p['closed'] else '')
for n,id,dist,whole,zoom in [(1,'CC01499',30,(30,-90,450,255),(240,100,320,195)),(2,'CC01504',9,(-225,-225,115,225),(-80,-35,45,25))]:
 row=json.loads((base/f'self-intersecting-case{n}-preview.json').read_text())[0]
 src=[native(s) for s in row['normalization']];ours=[native(p['segments']) for p in row['result']];their=up[id]['paths']
 out=['<svg xmlns="http://www.w3.org/2000/svg" width="1320" height="560" viewBox="0 0 1320 560">','<rect x="0" y="0" width="1320" height="560" fill="white"/>']
 def text(x,y,t,size=17):out.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="#334155">{escape(t)}</text>')
 text(20,32,f'Self-intersecting case {n} ({id}) — offset magnitude {dist}',23)
 text(20,60,'Gray: source · Blue: retained component · Orange: additional upstream open walk omitted by our output')
 for i,(box,title) in enumerate([(whole,'Our default trimmed output'),(whole,'Cavalier output'),(zoom,'Detail — both outputs')]):
  x=15+i*435;text(x+10,99,title,20)
  xmin,ymin,xmax,ymax=box;sc=min(385/(xmax-xmin),355/(ymax-ymin));cx=x+210;cy=297;mx=(xmin+xmax)/2;my=(ymin+ymax)/2
  out.append(f'<defs><clipPath id="clip{i}"><rect x="{x}" y="115" width="420" height="365"/></clipPath></defs><g clip-path="url(#clip{i})"><g transform="translate({cx} {cy}) scale({sc} {-sc}) translate({-mx} {-my})">')
  def draw(d,col,w):out.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w/sc}" stroke-linecap="round" stroke-linejoin="round"/>')
  for d in src:draw(d,'#94a3b8',1.8)
  if i in [0,2]:
   for d in ours:draw(d,'#2563eb',3)
  if i in [1,2]:
   for j,p in enumerate(their):
    if j==0 and i==2:continue
    col='#2563eb' if j==0 else '#d97706';draw(bulge(p),col,2.8)
    if not p['closed']:
     for v in [p['vertices'][0],p['vertices'][-1]]:out.append(f'<circle cx="{v[0]}" cy="{v[1]}" r="{4/sc}" fill="{col}"/>')
  out.append('</g></g>')
 if n==1:
  text(20,512,'Our result: one short open walk (length 24.81). Cavalier also returns the large open walk (length 1047.51).')
 else:text(20,512,'Our result: one closed contour. Cavalier also returns the interior open walk (length 137.48).')
 text(20,541,'Dots mark upstream open endpoints. Native output freshly replayed; Cavalier geometry from the pinned audit export.',15)
 out.append('</svg>');p=root/'examples/debug'/f'self-intersecting-case{n}-comparison.svg';p.write_text('\n'.join(out)+'\n');print(p)
