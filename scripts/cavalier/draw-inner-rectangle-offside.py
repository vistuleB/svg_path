from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
a=json.loads((root/'scripts/cavalier/inner-rectangle-offside-old.json').read_text());b=json.loads((root/'scripts/cavalier/inner-rectangle-offside-new.json').read_text())
def xy(p):return f'{p["x"]:.15g} {p["y"]:.15g}'
def path(ss):
 d='M '+xy(ss[0]['start'])
 for s in ss:
  if s['type']=='Line':d+=' L '+xy(s['end'])
  else:d+=f' A {xy(s["radius"])} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} '+xy(s['end'])
 return d
out=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="570" viewBox="0 0 1200 570">','<rect x="0" y="0" width="1200" height="570" fill="white"/>']
def text(x,y,s,size=18):out.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="#334155">{s}</text>')
text(20,32,'Inner rectangle alone — offset +1.2, Round joins, offside only',23)
text(20,61,'No outer rectangle. No final cusp or in-band trimming. Panels 2 and 3 use the same enlarged scale.')
for i,(title,sc,paths) in enumerate([('Source + untrimmed offset',130,a['raw']),('Previous score: one contour',330,a['result']),('New score: three contours',330,b['result'])]):
 x=i*400;text(x+15,103,title,20)
 out.append(f'<defs><clipPath id="p{i}"><rect x="{x+10}" y="120" width="380" height="365"/></clipPath></defs><g clip-path="url(#p{i})"><g transform="translate({x+200} 300) scale({sc} {-sc})">')
 for p in a['source']:out.append(f'<path d="{path(p["segments"])}" fill="none" stroke="#94a3b8" stroke-width="{2/sc}"/>')
 for j,p in enumerate(paths):
  col=['#2563eb','#a855f7','#d97706'][j%3] if i==2 else '#2563eb'
  out.append(f'<path d="{path(p["segments"])}" fill="none" stroke="{col}" stroke-width="{2.8/sc}"/>')
 out.append('</g></g>')
text(20,515,'Cause: minimizing submerged span can prefer a short submerged shortcut over a longer mixed route.')
text(20,545,'The remaining edges are then reconstructed as separate contours. This is a route-selection change, not rounding.')
out.append('</svg>');p=root/'examples/debug/inner-rectangle-offside-comparison.svg';p.write_text('\n'.join(out)+'\n');print(p)
