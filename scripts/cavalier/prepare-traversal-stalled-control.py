from pathlib import Path
import shutil, sys, re
root=Path(__file__).resolve().parents[2]
dest=Path('/tmp/cavalier-traversal-source-only' if '--source-only' in sys.argv else '/tmp/cavalier-traversal-stalled-control')
shutil.copytree(root/'test_portable/build/dev/javascript',dest,dirs_exist_ok=True)
p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text();start=s.index('function offset_nonempty_stalled_source_run(');end=s.index('\nfunction ',start+10);part=s[start:end]
needle='''(segment) => {
                  let $ = segment_is_finite(segment);'''
assert part.count(needle)==1
part=part.replace(needle,'''(segment) => {
                  const simplified=$degeneracy.segment_linearize_if_degenerate(segment,1e-9);
                  if(simplified.isOk() && simplified[0] instanceof Some) {
                    const pieces=[...simplified[0][0]];
                    if(pieces.length===1 && pieces[0] instanceof $svg_path.Line) segment=pieces[0];
                  }
                  let $ = segment_is_finite(segment);''')
if '--source-only' not in sys.argv:
    s=s[:start]+part+s[end:]
s=s.replace('export function public_error(error) {', 'export function public_error(error) { console.error(JSON.stringify(error,(k,v)=>v&&typeof v==="object"&&!Array.isArray(v)?{type:v.constructor.name,...v}:v));')
p.write_text(s)
p=dest/'svg_path/svg_path/internal/overlap_detection.mjs'
s=p.read_text()
s=re.sub(r'return new Error\(\s*\$svg_path.Error\$NonAffineOverlapCorrespondence\$const,\s*\);', 'console.error(JSON.stringify({left:{type:left.constructor.name,...left},right:{type:right.constructor.name,...right},tolerance}));return new Error($svg_path.Error$NonAffineOverlapCorrespondence$const);', s)
p.write_text(s)
print(dest)
