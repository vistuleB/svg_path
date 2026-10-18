from pathlib import Path
import json,hashlib,re,collections
root=Path(__file__).resolve().parent

def source(binary,name):
 if binary!='cavalier_contours':return 'tests/'+binary+'.rs'
 parts=name.split('::')
 for n in range(len(parts),0,-1):
  f='src/'+'/'.join(parts[:n])+'.rs'
  if (root/'upstream/cavalier_contours'/f).exists():return f
 return 'src/lib.rs'

rows=[]; tests={}; groups={}; kinds=collections.Counter()
def canon(p):
 if not isinstance(p,dict):return p
 if 'vertices' not in p:return {k:canon(v) for k,v in p.items()}
 vs=p['vertices']
 if p['closed'] and vs:vs=min(vs[i:]+vs[:i] for i in range(len(vs)))
 return {**p,'vertices':vs}
with open('/tmp/cavalier-capture.log') as inp:
 for l in inp:
  if '@AUDIT@' not in l:continue
  r=json.loads(l.split('@AUDIT@',1)[1]);r['binary']=re.sub(r'-[0-9a-f]+$','',r['binary']);kinds[r['kind']]+=1
  # Preserve direction; rotate closed start vertices only. Keep upstream policy settings and expectations.
  key={k:canon(v) for k,v in r.items() if k not in ('binary','test','result','positive','negative')}
  # Helper-only property comparisons outside the basic/view suites add little assertion coverage.
  if r['kind'] in ('area','path_length','extents') and r['binary'] not in ('test_pline_basics','test_pline_view'):
   key={'kind':r['kind'],'helper_only':True,'binary':r['binary'],'test':r['test']}
  h=hashlib.sha256(json.dumps(key,sort_keys=True).encode()).hexdigest()
  if h not in groups:
   groups[h]={'id':f'CC{len(groups)+1:05}',**r,'observations':0,'references':[],'helper_only':key.get('helper_only',False)}
  g=groups[h];g['observations']+=1
  ref={'binary':r['binary'],'file':source(r['binary'],r['test']),'test':r['test']}
  if ref not in g['references']:g['references'].append(ref)
import gzip
with gzip.open(root/'upstream-capture.log.gz','wb') as archive: archive.write(Path('/tmp/cavalier-capture.log').read_bytes())
records=list(groups.values())
(root/'captured-cases.json').write_text(json.dumps(records,indent=2)+'\n')
log=Path('/tmp/cavalier-capture.log').read_text()
summary={'captured_calls':dict(kinds),'representatives':len(records),'representatives_by_kind':dict(collections.Counter(r['kind'] for r in records)),'passed':sum(map(int,re.findall(r'test result: ok\. (\d+) passed',log))),'failed':sum(map(int,re.findall(r'; (\d+) failed;',log))),'raw_log_sha256':hashlib.sha256(log.encode()).hexdigest(),'raw_log_local_path':'/tmp/cavalier-capture.log','rotation_policy':'one representative per closed cyclic-start equivalence; both orientations retained','helper_policy':'area/length/extents outside basics/view grouped as helper-only, not comparison claims'}
(root/'capture-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
