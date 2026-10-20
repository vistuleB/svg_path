"""Test a dimensionful arc/line acceptance check in a copied JS build only."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parent
out=Path('/tmp/cavalier-endpoint-roundoff')
shutil.copytree(root/'probe/build/dev/javascript',out/'build',dirs_exist_ok=True)
p=out/'build/svg_path/svg_path.mjs'
s=p.read_text()
old='$float.absolute_value(cosine) <= (1.0 + cosine_tolerance)'
assert s.count(old)==1
p.write_text(s.replace(old,'($float.absolute_value(constant) - radius) <= signed_line_distance_tolerance'))
for name in ['probe-endpoint-minimal.mjs','probe-endpoint-crossing-roundoff.mjs']:
 s=(root/name).read_text().replace('./probe/build/dev/javascript/','./build/')
 (out/name).write_text(s)
print(out)
