"""Draw captured arrangement classifications, not inferred submerged geometry."""
from pathlib import Path
from html import escape
import json
root=Path(__file__).resolve().parents[2];base=root/'scripts/cavalier'
t=json.loads((base/'case11-cusp-trace.json').read_text())[0]
r=json.loads((base/'case11-cusp-only-result.json').read_text())[0]
failed=isinstance(r['result'],dict)
ambiguous=[38,45] if failed else []
p=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="470" viewBox="0 0 1440 470">','<rect x="0" y="0" width="1440" height="470" fill="white"/>']
def txt(x,y,s,size=16,color='#334155',weight='normal'):
 p.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(s)}</text>')
def d(s):
 a=s['start'];b=s['end'];out=f'M {a["x"]} {a["y"]}'
 if s['type']=='Line':out+=f' L {b["x"]} {b["y"]}'
 elif s['type']=='Arc':out+=f' A {s["radius"]["x"]} {s["radius"]["y"]} {s["x_axis_rotation"]} {int(s["large_arc"])} {int(s["sweep"])} {b["x"]} {b["y"]}'
 else:raise ValueError(s['type'])
 return out

def local(s):return all(135<=s[q]['x']<=180 and -22<=s[q]['y']<=5 for q in ['start','end'])
local_before=[s for s in t['before'] if local(s['segment'])]
n=sum(s['deletion_candidate'] for s in local_before)
txt(20,30,'Case11 · arrangement at cusp-only trimming · corrected join candidate',23,weight='bold')
txt(20,56,'offside: False · final_trimming: CuspTrimming · offset +9 in our API',16)
for i,title in enumerate(['1. Before rescue: winding classification','2. After submerged-run rescue','3. After deletion · before parity' if failed else '3. After cusp trimming']):
 x=12+478*i;p.append(f'<rect x="{x}" y="78" width="464" height="334" rx="8" fill="#f8fafc" stroke="#dbe3ec"/>');txt(x+12,104,title,17,weight='bold')
 p.append(f'<defs><clipPath id="panel{i}"><rect x="{x+7}" y="116" width="450" height="278"/></clipPath></defs><g clip-path="url(#panel{i})"><g transform="translate({x+232} 252) scale(9 -9) translate(-157.5 8.5)">')
 for src in r['normalization']:
  for s in src:p.append(f'<path d="{d(s)}" fill="none" stroke="#94a3b8" stroke-width="0.19"/>')
 if i<2:
  rows=t['before'] if i==0 else t['afterRescue']
  for s in sorted(rows,key=lambda s:s['deletion_candidate']):
   color='#dc2626' if s['deletion_candidate'] else '#2563eb'
   p.append(f'<path d="{d(s["segment"])}" fill="none" stroke="{color}" stroke-width="0.29" stroke-linecap="round"/>')
  for v in t['graph']['vertices']:
   q=v['point'];p.append(f'<circle cx="{q["x"]}" cy="{q["y"]}" r="0.19" fill="#334155" stroke="white" stroke-width="0.07"/>')
 elif failed:
  for entry in t['afterRescue']:
   if not entry['deletion_candidate']:p.append(f'<path d="{d(entry["segment"])}" fill="none" stroke="#2563eb" stroke-width="0.29"/>')
  for v in t['graph']['vertices']:
   if v['id'] in ambiguous:
    q=v['point'];p.append(f'<circle cx="{q["x"]}" cy="{q["y"]}" r="0.55" fill="#7c3aed" stroke="white" stroke-width="0.1"/>')
 else:
  for path in r['result']:
   for s in path['segments']:p.append(f'<path d="{d(s)}" fill="none" stroke="#2563eb" stroke-width="0.29"/>')
 p.append('</g></g>')
 remaining=sum(s['deletion_candidate'] for s in t['afterRescue'] if local(s['segment']))
 txt(x+12,397,[f'{n} fully visible pieces marked submerged',f'{remaining} local pieces remain marked for deletion','Parity ambiguous at purple vertices 38 and 45' if failed else 'Local loops remain'][i],15,'#b91c1c' if i==0 else '#334155')
 if failed and i==2:
  for v in t['graph']['vertices']:
   if v['id'] in ambiguous:
    q=v['point'];txt(x+232+9*(q['x']-157.5)-8,252-9*(q['y']+8.5)+23,str(v['id']),14,'#7c3aed','bold')
txt(20,438,'Red: marked submerged / deletion candidate · Blue: not marked for deletion · Gray: source · Dots: arrangement vertices',16)
txt(20,460,'Corrected joins carry reversed = True. Cusp-only reconstruction now fails; panel 3 is its surviving graph, not a returned path.' if failed else 'Rescue rule: a submerged run is retained if none of its pieces carries reversed = True.',15)
p.append('</svg>');out=root/'examples/debug'/('case11-cusp-metadata-trimming-stages.svg' if failed else 'case11-cusp-trimming-stages.svg');out.write_text('\n'.join(p)+'\n');print(out)
