from pathlib import Path
import json
root=Path(__file__).resolve().parent
r=json.loads((root/'cyclic-origin-trace.json').read_text())
def ls(x):
 if isinstance(x,list):return x
 out=[]
 while 'head' in x:out.append(x['head']);x=x['tail']
 return out
edges=ls(r['certified']['graph']['edges'])
print('sources',len(r['input']['segments']),'steps',len(r['steps']),'attachments',len(r['attachments']))
for row in r['certified']['edgeImages']:
 if row['edge_id'] in [10,11,14]:print('image',row)
for i,step in enumerate(r['steps']):
 before=ls(step['before']['edges']);after=ls(step['result']['graph']['edges'])
 if any(e['id']==14 for e in after) and not any(e['id']==14 for e in before):
  print('edge14 created at step',step.get('step_index',i),'piece',step['piece']);print('vertices',ls(step['result']['graph']['vertices']))
print('sources')
for i,s in enumerate(r['input']['segments']):print(i,s)
print('final target vertices')
for v in ls(r['certified']['graph']['vertices']):
 if v['id'] in [10,11,13]:print(v)
