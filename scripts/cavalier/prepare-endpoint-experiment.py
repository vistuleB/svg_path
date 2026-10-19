"""Experiment on a copied generated JS build; production source is untouched."""
from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-endpoint-experiment')
shutil.copytree(root/'scripts/cavalier/probe/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/intersections.mjs'
s=p.read_text()
s,n=re.subn(r'(elizabeth_endpoint_candidates\(\s*left,\s*right,\s*)(?:original_tolerance|tolerance)(,)',r'\g<1>options.tolerance\2',s)
assert n==2,n
p.write_text(s)
for name in ['probe-endpoint-minimal.mjs','probe-endpoint-tolerance.mjs']:
 s=(root/'scripts/cavalier'/name).read_text()
 s=s.replace('./probe/build/dev/javascript/','/tmp/cavalier-endpoint-experiment/').replace('../../test_portable/build/dev/javascript/','/tmp/cavalier-endpoint-experiment/')
 s=s.replace("new URL('./elementary-triage-cases.json',import.meta.url)",repr(str(root/'scripts/cavalier/elementary-triage-cases.json')))
 (target/name).write_text(s)
