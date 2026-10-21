"""Draw captured rescue fallback and the cycles rejected by the cusp-only API."""
from pathlib import Path
from html import escape
import json
root=Path(__file__).resolve().parents[2];b=root/'scripts/cavalier'
t=json.loads((b/'case11-cusp-fallback-trace.json').read_text())[0]
r=json.loads((b/'case11-cusp-fallback-result.json').read_text())[0]
a=t['attempts'];assert len(a)==2 and a[0]['result']['type']=='Error' and a[1]['result']['type']=='Ok'
revoked=[i for i,(x,y) in enumerate(zip(a[0]['current'],a[1]['current'])) if not x['deletion_candidate'] and y['deletion_candidate']]
assert len(revoked)==4
assert all(t['before'][i]['deletion_candidate'] for i in revoked)
assert all(not x['deletion_candidate'] or y['deletion_candidate'] for x,y in zip(a[0]['current'],a[1]['current']))
cycles=a[1]['result']['0'];assert len(cycles)==2 and all(c['closed'] for c in cycles)
p=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="470" viewBox="0 0 1440 470">','<rect x="0" y="0" width="1440" height="470" fill="white"/>']
def text(x,y,s,size=16,color='#334155'):
 p.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}">{escape(s)}</text>')
def d(s):
 x=s['start'];y=s['end'];z=f'M {x["x"]} {x["y"]}'
 if s['type']=='Arc':z+=f' A {s["radius"]["x"]} {s["radius"]["y"]} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} {y["x"]} {y["y"]}'
 else:z+=f' L {y["x"]} {y["y"]}'
 return z
text(20,30,'Case11 — revoke rescue at ambiguous vertices',23)
text(20,56,'Cusp-only trimming · offside disabled · corrected joins and reversal metadata',16)
for i,title in enumerate(['1. Initial rescue: parity ambiguous','2. Four rescues revoked: parity succeeds','3. Reconstructed cycles (not returned)']):
 x=12+478*i;p.append(f'<rect x="{x}" y="78" width="464" height="334" rx="8" fill="#f8fafc" stroke="#dbe3ec"/>');text(x+12,104,title,17)
 p.append(f'<defs><clipPath id="p{i}"><rect x="{x+7}" y="116" width="450" height="278"/></clipPath></defs><g clip-path="url(#p{i})"><g transform="translate({x+232} 252) scale(9 -9) translate(-157.5 8.5)">')
 def draw(s,color,width=.29):p.append(f'<path d="{d(s)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')
 for sub in r['normalization']:
  for s in sub:draw(s,'#94a3b8',.19)
 if i<2:
  for s in sorted(a[i]['current'],key=lambda s:s['deletion_candidate']):draw(s['segment'],'#dc2626' if s['deletion_candidate'] else '#2563eb')
  for v in t['graph']['vertices']:
   q=v['point'];p.append(f'<circle cx="{q["x"]}" cy="{q["y"]}" r="0.19" fill="#334155" stroke="white" stroke-width="0.07"/>')
 else:
  for c in cycles:
   for e in c['edges']:draw(e['segment'],'#7c3aed' if len(c['edges'])==8 else '#2563eb')
 p.append('</g></g>');text(x+12,397,['Originally rescued edges remain blue','Four additional pieces are now red','Purple: separate 8-edge closed loop'][i],15)
text(20,438,'Red: deletion candidates · Blue: retained geometry / main cycle · Gray: source · Purple: extra cycle',16)
text(20,460,'Parity is resolved, but the public call returns ConstructionFailed: cusp-only trimming rejects the two-cycle result.',15)
p.append('</svg>');out=root/'examples/debug/case11-cusp-fallback.svg';out.write_text('\n'.join(p)+'\n');print(out)
print('Verified: one retry, four eligible rescues revoked, two closed cycles.')
