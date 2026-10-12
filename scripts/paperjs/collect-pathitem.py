import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
fixtures=json.loads((root/'scripts/paperjs/pathitem.json').read_text())['fixtures']
def expected(value):
 subs=[value] if isinstance(value[0][0],(int,float)) else value
 result=[]
 for nodes in subs:
  closed=nodes[-1] is True;nodes=nodes[:-1] if closed else nodes;curves=[]
  for i in range(len(nodes) if closed else len(nodes)-1):
   a=nodes[i];b=nodes[(i+1)%len(nodes)];out=a[4:6] if len(a)>2 else [0,0];inc=b[2:4] if len(b)>2 else [0,0]
   curves.append(a[:2]+[a[0]+out[0],a[1]+out[1],b[0]+inc[0],b[1]+inc[1]]+b[:2])
  result.append([[1 if closed else 0]]+curves)
 return result
def drop_empty(rows):return rows[:1]+[c for c in rows[1:] if not all(c[i:i+2]==c[:2] for i in [2,4,6])]
reports={}
for target,filename in zip(['erlang','javascript'],sys.argv[1:]):
 rows=[]
 for line in Path(filename).read_text().splitlines():
  m=re.match(r'^(\d+):(.*)$',line)
  if not m:continue
  id=int(m[1]);raw=m[2];f=fixtures[id];r={'id':id,'input':f['input'],'raw':raw}
  if not raw.startswith('Ok('):r.update(status='library-error')
  else:
   actual=list(map(drop_empty,json.loads(raw[3:-1])));want=list(map(drop_empty,expected(f['expected'])))
   structural=len(actual)==len(want) and all(len(a)==len(b) and a[0]==b[0] for a,b in zip(actual,want))
   error=max(abs(x-y) for a,b in zip(actual,want) for c,d in zip(a,b) for x,y in zip(c,d)) if structural else None
   r.update(status='match' if structural and error<=0.00002 else 'discrepancy',maxCoordinateError=error,tolerance=0.00002)
  rows.append(r)
 assert [r['id'] for r in rows]==list(range(22));reports[target]=rows
 print(target,{s:sum(r['status']==s for r in rows) for s in ['match','discrepancy','library-error']})
 print([r for r in rows if r['status']!='match'])
assert len(reports)==2
(root/'scripts/paperjs/pathitem-native-screening.json').write_text(json.dumps(reports,indent=2)+'\n')
