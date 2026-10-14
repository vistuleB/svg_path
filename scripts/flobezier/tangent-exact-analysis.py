import json, math
from decimal import Decimal, getcontext
getcontext().prec=90
D=Decimal
source=json.load(open('scripts/flobezier/tangent-investigation.json'))
def eval_at(ps,t):
    pts=[[D(c) for c in p] for p in ps]
    while len(pts)>1:
        pts=[[(1-t)*a+t*b for a,b in zip(p,q)] for p,q in zip(pts,pts[1:])]
    return pts[0]
def distance(a,b):return sum((x-y)**2 for x,y in zip(a,b)).sqrt()
summary=[]
for row in source['rows']:
    refs=row['reference']; endpoints=[r for r in refs if r['t1'] in (0,1) and r['t2'] in (0,1)]
    out=[]
    for hit in row['current']['values']:
        t=D.from_float(hit['left_t']);u=D.from_float(hit['right_t'])
        residual=distance(eval_at(row['left'],t),eval_at(row['right'],u))
        nearest=min(refs,key=lambda r:max(abs(hit['left_t']-r['t1']),abs(hit['right_t']-r['t2'])))
        nearest_endpoint=min(endpoints,key=lambda r:max(abs(hit['left_t']-r['t1']),abs(hit['right_t']-r['t2'])))
        out.append({'t':float(t),'u':float(u),'residual90':str(residual),'nearest_reference_is_endpoint':nearest in endpoints,'endpoint_parameter_distance':max(abs(hit['left_t']-nearest_endpoint['t1']),abs(hit['right_t']-nearest_endpoint['t2']))})
    summary.append({'call':row['call'],'reference_count':len(refs),'current_count':len(out),'hits':out})
    print(row['call'],len(refs),len(out), 'residual max',max(D(x['residual90']) for x in out),'endpoint candidate distances', [x['endpoint_parameter_distance'] for x in out if x['nearest_reference_is_endpoint']])
json.dump(summary,open('scripts/flobezier/tangent-exact-analysis.json','w'),indent=2)
# For call1268, u=1-t_left, v=1-t_right; eliminate the common tangent.
# 399 u² = 1307 v², then solve x equation for each u/v sign.
k=(D(1307)/399).sqrt()
for ratio in [k,-k]:
    v=(384-192*ratio)/(358-174*ratio**2)
    u=ratio*v
    print('1268 nonzero solution: u=',u,'v=',v,' original t,s=',1-u,1-v)
