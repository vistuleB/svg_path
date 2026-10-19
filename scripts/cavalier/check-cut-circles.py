import json, math
from decimal import Decimal as D, localcontext

def point(p):return D(p['x']),D(p['y'])
def sub(a,b):return a[0]-b[0],a[1]-b[1]
def dot(a,b):return a[0]*b[0]+a[1]*b[1]
def center(s):
 a,b=point(s['start']),point(s['end']);r=D(s['radius']['x']);dx,dy=sub(b,a)
 h=(r*r/(dx*dx+dy*dy)-D('.25')).sqrt()
 if s['large_arc']==s['sweep']:h=-h
 return ((a[0]+b[0])/2-dy*h,(a[1]+b[1])/2+dx*h),r
rows=[json.loads(x[9:]) for x in open('scripts/cavalier/near-tangent-cut-provenance.log') if x.startswith('CUTTRACE ')]
with localcontext() as ctx:
 ctx.prec=70
 for i,row in enumerate(rows):
  if row['kind']!='pair-cuts':continue
  a,b=row['edge']['segment'],row['piece']['segment']
  if 'radius' not in a or 'radius' not in b:continue
  c,r=center(a);d,s=center(b);v=sub(d,c);dist=dot(v,v).sqrt()
  hits=[]
  if abs(r-s)<=dist<=r+s:
   along=(r*r-s*s+dist*dist)/(2*dist);height=(r*r-along*along).sqrt()
   for sign in [-1,1]:
    hit=(c[0]+along*v[0]/dist-sign*height*v[1]/dist,c[1]+along*v[1]/dist+sign*height*v[0]/dist)
    ts=[]
    for seg,cc in [(a,c),(b,d)]:
     u=sub(point(seg['start']),cc);w=sub(point(seg['end']),cc);z=sub(hit,cc)
     sweep=math.atan2(float(u[0]*w[1]-u[1]*w[0]),float(dot(u,w)))
     angle=math.atan2(float(u[0]*z[1]-u[1]*z[0]),float(dot(u,z)))
     ts.append(angle/sweep)
    hits.append(ts)
  print(json.dumps({'event':i,'from':row['piece']['source_from'],'to':row['piece']['source_to'],'center_a':[str(x) for x in c],'center_b':[str(x) for x in d],'outer_gap':str(dist-r-s),'inner_gap':str(abs(r-s)-dist),'circle_hit_parameters':hits,'cuts':row['cuts']}))
