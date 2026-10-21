"""Create a focused dual-target harness; production dependency stays in this repo."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
dest=Path('/tmp/csg-affine-focused')
for d in ['src','test']: (dest/d).mkdir(parents=True,exist_ok=True)
(dest/'gleam.toml').write_text('name = "csg_affine_focused"\nversion = "0.0.0"\n[dependencies]\nsvg_path = { path = "'+str(root)+'" }\ngleam_stdlib = ">= 1.0.0 and < 2.0.0"\n[dev_dependencies]\ngleeunit = ">= 1.0.0 and < 2.0.0"\n')
files=sorted((root/'test').glob('svg_path_csg*test.gleam'))
files += [root/'test'/name for name in ['svg_path_arc_test.gleam','svg_path_transform_test.gleam'] if (root/'test'/name).exists()]
for p in files: shutil.copy2(p,dest/'test'/p.name)
(dest/'test/csg_affine_focused_test.gleam').write_text('import gleeunit\npub fn main() { gleeunit.main() }\n')
# A fresh directory may require gleam deps download; do not reuse a stale manifest.
for name in ['triage-geometry.mjs','probe-csg-reconstruction-all.mjs']:
 s=(root/'scripts/cavalier'/name).read_text().replace('../../test_portable/build/dev/javascript',str(dest/'build/dev/javascript'))
 for f in ['captured-cases.json','discrepancy-queue.json']:s=s.replace("new URL('./"+f+"',import.meta.url)",repr(str(root/'scripts/cavalier'/f)))
 s=s.replace('&&shape(s)===shape(out)','&&(!(out instanceof g.Arc)||(s.large_arc===out.large_arc&&s.sweep===out.sweep))')
 (dest/name).write_text(s)
print(dest)
