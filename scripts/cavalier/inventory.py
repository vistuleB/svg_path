"""Pin archive provenance and extract the complete test_simple offset macro block."""
from pathlib import Path
import hashlib,json,re,datetime
root=Path(__file__).resolve().parent
up=root/'upstream'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
provenance={'repository':'https://github.com/jbuckmccready/cavalier_contours','revision':'22887a824d22cd8ab50968a551f34cdb4508127f','version':'0.9.0','download_date':'2026-10-16','archive_sha256':sha(Path('/tmp/cavalier-audit.tar.gz')),'files':{str(p.relative_to(up)):sha(p) for p in sorted(up.rglob('*')) if p.is_file()}}
(root/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
source=up/'cavalier_contours/tests/test_pline_parallel_offset.rs'
s=source.read_text().split('mod test_simple {',1)[1].split('mod test_specific {',1)[0]
fixtures=[]
for name,body in re.findall(r'^        (\w+) \{(.*?)^        \}',s,re.M|re.S):
 if name=='empty_returns_empty':
  fixtures.append(dict(name=name,closed=False,vertices=[],offset=5,expected=[]));continue
 m=re.search(r'pline_(closed|open)_userdata!\[\[4\],(.*?)\],\s*([\d.\-]+)\)\s*=>',body,re.S)
 assert m,name
 vertices=[[float(x.strip()) for x in t.split(',')] for t in re.findall(r'\(([^()]*)\)',m[2])]
 props=[]
 for p in re.findall(r'PlineProperties::new\((.*?),\s*vec!\[4\]\)',body,re.S):
  v=[float(x.strip()) for x in p.split(',')]
  assert len(v)==7
  props.append(dict(vertex_count=int(v[0]),area=v[1],length=v[2],bounds=v[3:]))
 fixtures.append(dict(name=name,closed=m[1]=='closed',vertices=vertices,offset=float(m[3]),expected=props))
assert len(fixtures)==16,len(fixtures)
(root/'offset-simple-fixtures.json').write_text(json.dumps(fixtures,indent=2)+'\n')
files=sorted((up/'cavalier_contours/tests').glob('test_*.rs'))
(root/'INDEX.md').write_text('# Cavalier Contours audit inventory\n\nOriginal filenames are preserved under `upstream/`. Pending means unreviewed.\nThis index covers core integration-test files; unit tests, FFI and examples remain outside this initial inventory.\n\n| File | Status |\n| --- | --- |\n'+''.join(f'| `{p.name}` | '+('`test_simple`: 16 fixtures extracted; other modules pending' if p==source else 'Pending')+' |\n' for p in files))
print(len(files),'integration files;',len(fixtures),'simple fixtures')
