"""Temporary JS-only arc correspondence direction experiment, not a source patch."""
from pathlib import Path
import shutil
repo=Path(__file__).resolve().parents[2]
root=Path('/tmp/fl006-overlap-runtime');shutil.copytree(repo/'test_portable/build/dev/javascript',root,dirs_exist_ok=True)
p=root/'svg_path/svg_path/internal/overlap_detection.mjs';s=p.read_text();needle='function sampled_overlap_valid(overlap, left, right, tolerance, samples) {'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
  if (left instanceof $svg_path.Arc && right instanceof $svg_path.Arc) {
    const a=$svg_path.segment_derivative(left,(overlap[0]+overlap[1])/2);
    const b=$svg_path.segment_derivative(right,(overlap[2]+overlap[3])/2);
    if(a.isOk() && b.isOk()) {
      const dot=a[0].x*b[0].x+a[0].y*b[0].y;
      if(dot*(overlap[1]-overlap[0])*(overlap[3]-overlap[2])<=0) return new Ok(false);
    }
  }
''');p.write_text(s)
out=Path('/tmp/fl006-overlap-tools');out.mkdir(exist_ok=True)
base=repo/'scripts/flatten'
for name in ['compare-arc-circle.mjs','continuity-adapter.mjs','probe-continuity-4295.mjs','probe-continuity-chains.mjs','probe-continuity.mjs','probe-fl006-short-overlap.mjs']:
 (out/name).write_text((base/name).read_text().replace('../../test_portable/build/dev/javascript',str(root)))
for name in ['polygons-calls.jsonl','remaining-fl006-experiment.json']:
 shutil.copy2(base/name,out/name)
print(out)
