from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-cyclic-origin-trace')
shutil.copytree(root/'scripts/cavalier/probe/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
for name in ['build_with','certify_segment_build','progressive_insert_piece','attach_vertex']:
 import re
 pattern=r'(export )?function '+name+r'\('
 m=re.search(pattern,s);assert m,name
 s=re.sub(pattern,'function original_'+name+'(',s,count=1)
 if name=='build_with':
  s+='''
export function build_with(...args) {
 globalThis.originInput={segments:[...args[0]],options:args.slice(1)};
 globalThis.originSteps=[];globalThis.originAttachments=[];
 return original_build_with(...args);
}
'''
 elif name=='certify_segment_build':
  s+='''
function certify_segment_build(...args) {
 const r=original_certify_segment_build(...args);
 globalThis.originCertified={graph:args[0],segments:[...args[1]],images:[...args[2]],edgeImages:[...args[3]],result:r.isOk()};
 return r;
}
'''
 elif name=='progressive_insert_piece':
  s+='''
function progressive_insert_piece(...args) {
 const r=original_progressive_insert_piece(...args);
 if(r.isOk()) (globalThis.originSteps??=[]).push({piece:args[0],before:args[1],result:r[0]});
 return r;
}
'''
 else:
  s+='''
function attach_vertex(...args) {
 const r=original_attach_vertex(...args);
 (globalThis.originAttachments??=[]).push({endpoint:args[1],owner:r[1],vertex:[...r[0]].find(v=>v.id===r[1])});
 return r;
}
'''
p.write_text(s)
