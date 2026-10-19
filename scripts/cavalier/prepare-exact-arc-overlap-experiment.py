"""Copied-build experiment: prefer an already validated exact full arc map."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2];target=Path('/tmp/cavalier-exact-arc-overlap')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/internal/overlap_detection.mjs';s=p.read_text()
needle='function prefer_certified_full_overlap(candidates, left, right, tolerance) {'
assert needle in s
s=s.replace(needle,needle+'''
 if(left instanceof $svg_path.Arc && right instanceof $svg_path.Arc) {
  const forward=JSON.stringify(left)===JSON.stringify(right);
  const backward=JSON.stringify(left)===JSON.stringify($svg_path.segment_reverse(right));
  for(const c of candidates) {
   if(c[0]===0 && c[1]===1 && ((forward && c[2]===0 && c[3]===1)||(backward && c[2]===1 && c[3]===0))) {
    return listPrepend(c, $List$Empty$const);
   }
  }
 }
''',1);p.write_text(s)
for name in ['probe-short-reversed-arc.mjs','probe-tangent-arc-contours.mjs']:
 s=(root/'scripts/cavalier'/name).read_text().replace('../../test_portable/build/dev/javascript',str(target))
 (root/'scripts/cavalier'/name.replace('.mjs','-experiment.mjs')).write_text(s)
