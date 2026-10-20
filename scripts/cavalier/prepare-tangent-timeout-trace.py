"""Copy the JS build and log completed/active calls without changing results."""
from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-tangent-timeout-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
for module,names in {
 'offset':['single_offset_segment_arrangement','offside_trimmed_single_offset_subpath','trim_single_offset_arrangement','forced_parity_reduce_trim_graph'],
 'arrangement':['build_with','pair_cuts_with_common_endpoint_sliver'],
 'intersections':['curve_curve_intersections','shared_endpoint_circle_intersections'],
}.items():
 p=target/f'svg_path/svg_path/{module}.mjs';s=p.read_text()
 for name in names:
  pattern=r'(export )?function '+name+r'\('
  match=re.search(pattern,s);assert match,name
  s=re.sub(pattern,'function audit_original_'+name+'(',s,count=1)
  s+='''
%sfunction %s(...args) {
 const id=globalThis.auditNext=(globalThis.auditNext??0)+1;
 const t=performance.now(), key='%s.%s';
 console.error(JSON.stringify({event:'enter',id,key,...(key.startsWith('intersections.')?{args}:{} )}));
 const r=audit_original_%s(...args);
 console.error(JSON.stringify({event:'exit',id,key,milliseconds:performance.now()-t,resultType:r?.constructor?.name,...(key.startsWith('intersections.')?{result:r}:{} )}));
 return r;
}
'''%('export ' if match.group(1) else '',name,module,name,name)
 p.write_text(s)
