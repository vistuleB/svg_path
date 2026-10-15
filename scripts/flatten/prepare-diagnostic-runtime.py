"""Copy generated JavaScript to /tmp; expose hidden diagnostics without editing source."""
from pathlib import Path
import shutil,tempfile,re,sys
source=Path(__file__).resolve().parents[2]/'test_portable/build/dev/javascript'
target=Path(tempfile.mkdtemp(prefix='flatten-diagnostic-'))/'javascript'
shutil.copytree(source,target)
p=target/'svg_path/svg_path/arrangement.mjs'
s=p.read_text();needle='export function public_error(error) {';assert needle in s
s=s.replace(needle,needle+'\n  return error; // diagnostic copy only: preserve hidden error payload\n',1);p.write_text(s)
p=target/'svg_path/svg_path/intersections.mjs';s=p.read_text();needle='''return new Error(
              Error$InternalOverlapClassificationInconsistency$const,'''
assert needle in s
s=s.replace(needle,'''console.error('OVERLAP_INCONSISTENCY',JSON.stringify({left,right,options}));
            '''+needle,1);p.write_text(s)
# Bound the diagnostic run and report search growth on the reduced distance query.
s=p.read_text()
s,count=re.subn(r'(function inspect_projection_window\([\s\S]*?\) \{)',r"\1\n  globalThis.flattenWindows=(globalThis.flattenWindows??0)+1;\n  if(globalThis.flattenWindows===200000)throw {diagnosticStop:true,windows:globalThis.flattenWindows,remaining_depth,best};",s,count=1)
assert count==1
if '--without-arc-bound' in sys.argv:
    needle='function arc_projection_window_bound(left, right, box_bound, best) {'
    assert needle in s
    s=s.replace(needle,needle+'\n  return new Ok([box_bound,best]); // diagnostic baseline only\n',1)
p.write_text(s)
print(target.as_uri()+'/')
