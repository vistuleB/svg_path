from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
r=json.loads((root/'scripts/cavalier/self-case1-cusp-output.json').read_text())[0]
def xy(p):return f'{p["x"]:.14g} {p["y"]:.14g}'
def path(ss):
 d='M '+xy(ss[0]['start'])
 for s in ss:
  if s['type']=='Line':d+=' L '+xy(s['end'])
  elif s['type']=='Arc':d+=f' A {xy(s["radius"])} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} '+xy(s['end'])
  else:raise ValueError(s['type'])
 return d
out=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="610" viewBox="0 0 1200 610">','<rect x="0" y="0" width="1200" height="610" fill="white"/>']
def text(x,y,s,size=18):out.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="#334155">{s}</text>')
text(20,32,'Self-intersecting case 1 — cusp trimming, no in-band trimming',23)
text(20,62,'Gray: source · Blue: offset magnitude 30 · Dots: output endpoints')
for i,(x,w,box,title) in enumerate([(15,690,(30,-90,450,255),'Full output'),(735,450,(235,95,325,185),'Detail near the crossing')]):
 xmin,ymin,xmax,ymax=box;sc=min((w-35)/(xmax-xmin),410/(ymax-ymin));cx=x+w/2;cy=330;mx=(xmin+xmax)/2;my=(ymin+ymax)/2
 text(x+10,105,title,20)
 out.append(f'<defs><clipPath id="p{i}"><rect x="{x}" y="125" width="{w}" height="420"/></clipPath></defs><g clip-path="url(#p{i})"><g transform="translate({cx} {cy}) scale({sc} {-sc}) translate({-mx} {-my})">')
 for ss in r['normalization']:out.append(f'<path d="{path(ss)}" fill="none" stroke="#94a3b8" stroke-width="{2/sc}"/>')
 for p in r['result']:
  ss=p['segments'];out.append(f'<path d="{path(ss)}" fill="none" stroke="#2563eb" stroke-width="{2.8/sc}" stroke-linejoin="round"/>')
  for v in [ss[0]['start'],ss[-1]['end']]:out.append(f'<circle cx="{v["x"]}" cy="{v["y"]}" r="{4/sc}" fill="#2563eb"/>')
 out.append('</g></g>')
text(20,582,'One open output walk, 11 segments, length 1154.28644. Offside is enabled but does not trim this open source.',16)
out.append('</svg>');p=root/'examples/debug/self-case1-cusp-trimming.svg';p.write_text('\n'.join(out)+'\n');print(p)
