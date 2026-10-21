"""Preview current native case11/case5 output against pinned Cavalier geometry."""
from pathlib import Path
import json,math,sys
from html import escape
root=Path(__file__).resolve().parents[2];base=root/'scripts/cavalier'
up={r['id']:r for r in map(json.loads,(base/'original-offset-specific-upstream.jsonl').read_text().splitlines())}
def xy(p):return f'{p["x"]:.14g} {p["y"]:.14g}'
def native(segments):
 d='M '+xy(segments[0]['start'])
 for s in segments:
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
for name,id,dist,whole,zoom in [('case11','CC01405',9,(-360,-35,410,242),(115,-28,200,12)),('case5','CC01470',30,(40,-85,445,250),(40,65,115,135))]:
 untrimmed='--untrimmed' in sys.argv
 candidate='--cusp-candidate' in sys.argv
 if (untrimmed or candidate) and name!='case11':continue
 row=json.loads((base/(('case11-cusp-candidate-raw.json' if untrimmed else 'case11-cusp-candidate.json') if candidate else name+('-untrimmed-preview.json' if untrimmed else '-preview.json'))).read_text())[0]
 src=[native(s) for s in row['normalization']];ours=[native(s['segments']) for s in row['result']];theirs=[bulge(p) for p in up[id]['paths']]
 if untrimmed:
  theirs=[native(s['segments']) for s in json.loads((base/('case11-cusp-candidate.json' if candidate else name+'-preview.json')).read_text())[0]['result']]
 out=['<svg xmlns="http://www.w3.org/2000/svg" width="1180" height="460" viewBox="0 0 1180 460">','<rect x="0" y="0" width="1180" height="460" fill="white"/>']
 def text(x,y,t,size=16,color='#334155',weight='normal'):
  out.append(f'<text x="{x}" y="{y}" font-family="Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(t)}</text>')
 text(20,30,f'{name} ({id}) — offset magnitude {dist}',23,weight='bold')
 text(20,57,'Gray: source   ·   Orange: our untrimmed offset   ·   Blue: our default trimmed output' if untrimmed else 'Gray: source   ·   Blue: our default trimmed output   ·   Orange: Cavalier Preserve output',16)
 for i,(box,title,x,width) in enumerate([(whole,'Whole shape · boxed region enlarged at right',16,420),(zoom,'Detail — our result',450,350),(zoom,'Detail — Cavalier result',814,350)]):
  out.append(f'<rect x="{x}" y="78" width="{width}" height="330" rx="8" fill="#f8fafc" stroke="#dbe3ec"/>');text(x+12,103,('Whole shape — untrimmed' if i==0 else 'Detail — untrimmed' if i==1 else 'Detail — default trimmed') if untrimmed else title,16,weight='bold')
  xmin,ymin,xmax,ymax=box;sc=min((width-36)/(xmax-xmin),265/(ymax-ymin));cx=x+width/2;cy=255;mx=(xmin+xmax)/2;my=(ymin+ymax)/2
  out.append(f'<defs><clipPath id="clip{i}"><rect x="{x+8}" y="116" width="{width-16}" height="280"/></clipPath></defs><g clip-path="url(#clip{i})"><g transform="translate({cx} {cy}) scale({sc} {-sc}) translate({-mx} {-my})">')
  def draw(paths,color,w,dash=''):
   for d in paths:out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w/sc}" stroke-linecap="round" stroke-linejoin="round"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
  draw(src,'#94a3b8',2)
  if i in [0,1]:draw(ours,'#d97706' if untrimmed else '#2563eb',2.6)
  if i==2 or (i==0 and not untrimmed):draw(theirs,'#2563eb' if untrimmed else '#d97706',2.4, f'{5/sc} {4/sc}' if i==0 else '')
  if i==0:
   a,b,c,d=zoom;out.append(f'<rect x="{a}" y="{b}" width="{c-a}" height="{d-b}" fill="none" stroke="#475569" stroke-width="{1/sc}" stroke-dasharray="{4/sc} {3/sc}"/>')
  out.append('</g></g>')
 if untrimmed:text(20,438,'Untrimmed means offside disabled and final_trimming: NoTrimming. The right panel shows what default trimming retains.',15)
 elif name=='case11':text(20,438,'Difference: our two offset arcs meet at a higher cusp; Cavalier retains the lower connecting arc.',16)
 else:text(20,438,'Difference near the open start: we retain the collapsed-arc portion and more of its round join.',16)
 out.append('</svg>');file=root/'examples/debug'/((f'{name}-cusp-candidate-untrimmed.svg' if untrimmed else f'{name}-cusp-candidate.svg') if candidate else (f'{name}-untrimmed-comparison.svg' if untrimmed else f'{name}-offset-comparison.svg'));file.write_text('\n'.join(out)+'\n');print(file)
