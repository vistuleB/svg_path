"""Diagnostic direction guard only; never changes source or the normal build."""
from pathlib import Path
import tempfile,shutil
source=Path(__file__).resolve().parents[2]/'test_portable/build/dev/javascript'
target=Path(tempfile.mkdtemp(prefix='fl004-direction-'))/'javascript'
shutil.copytree(source,target)
p=target/'svg_path/svg_path/internal/overlap_detection.mjs'
s=p.read_text();needle='function line_correspondence_valid(overlap, left, right, tolerance) {'
assert needle in s
s=s.replace(needle,needle+'''
  const dx=left.end.x-left.start.x,dy=left.end.y-left.start.y;
  const ex=right.end.x-right.start.x,ey=right.end.y-right.start.y;
  if((dx*ex+dy*ey)*(overlap[1]-overlap[0])*(overlap[3]-overlap[2])<=0)return new Ok(false);
''',1);p.write_text(s)
print(target.as_uri()+'/')
