import json,gzip,hashlib,re,collections
from pathlib import Path
root=Path(__file__).resolve().parent

def source(binary,name):
 if binary!='cavalier_contours':return 'tests/'+binary+'.rs'
 parts=name.split('::')
 for n in range(len(parts),0,-1):
  f='src/'+'/'.join(parts[:n])+'.rs'
  if (root/'upstream/cavalier_contours'/f).exists():return f
 return 'src/lib.rs'

kinds={'seg_arc_radius_and_center','seg_length','seg_midpoint','seg_bounding_box','seg_fast_approx_bounding_box','seg_split_at_point','seg_tangent_vector','seg_closest_point','seg_distance_is_greater_than','dist_from_segment_start','find_point_at_path_length'}
groups={};raw=Path('/tmp/cavalier-extra-capture.log').read_bytes()
for l in raw.decode().splitlines():
 if '@AUDIT@' not in l:continue
 r=json.loads(l.split('@AUDIT@',1)[1]);r['binary']=re.sub(r'-[0-9a-f]+$','',r['binary'])
 if r['kind'] not in kinds:continue
 key=json.dumps({k:v for k,v in r.items() if k not in ['test','binary']},sort_keys=True)
 if key not in groups:groups[key]={'id':f'CX{len(groups)+1:05}',**r,'observations':0,'references':[]}
 g=groups[key];g['observations']+=1;ref={'binary':r['binary'],'file':source(r['binary'],r['test']),'test':r['test']}
 if ref not in g['references']:g['references'].append(ref)
records=list(groups.values());(root/'extra-cases.json').write_text(json.dumps(records,indent=2)+'\n')
with gzip.open(root/'upstream-extra-capture.log.gz','wb') as f:f.write(raw)
summary={'representatives':len(records),'by_kind':dict(collections.Counter(r['kind'] for r in records)),'passed':sum(map(int,re.findall(r'test result: ok\. (\d+) passed',raw.decode()))),'failed':sum(map(int,re.findall(r'; (\d+) failed;',raw.decode()))),'sha256':hashlib.sha256(raw).hexdigest()}
(root/'extra-capture-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
