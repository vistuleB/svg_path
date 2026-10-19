"""Instrument a copied generated JS build; never modify library source/build."""
from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-tangent-instrumented')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
for module,names in {
 'offset':['offside_trimmed_single_offset_subpath','single_offset_segment_arrangement','trim_single_offset_arrangement','forced_parity_reduce_trim_graph'],
 'arrangement':['build_with','pair_cuts_with_common_endpoint_sliver','split_atomic_piece'],
 'intersections':['curve_curve_intersections','shared_endpoint_circle_intersections'],
}.items():
 p=target/f'svg_path/svg_path/{module}.mjs';s=p.read_text()
 for name in names:
  pattern=r'(export )?function '+name+r'\('
  match=re.search(pattern,s)
  if not match: raise RuntimeError(name)
  exported=bool(match.group(1));s=re.sub(pattern,'function audit_original_'+name+'(',s,count=1)
  s+='''
%sfunction %s(...args) {
 const t=performance.now();
 const r=audit_original_%s(...args);
 const ms=performance.now()-t;
 const key='%s.%s';
 const stats=(globalThis.auditTiming??={});
 const row=stats[key]??={calls:0,milliseconds:0,maxMilliseconds:0};
 row.calls++;row.milliseconds+=ms;row.maxMilliseconds=Math.max(row.maxMilliseconds,ms);
 if(key.includes('intersections.curve') && ms>50) {
  (globalThis.auditSlowPairs??=[]).push({milliseconds:ms,left:args[0],right:args[1],options:args[2],result:r});
 }
 return r;
}
'''%('export ' if exported else '',name,name,module,name)
 p.write_text(s)
s=(root/'scripts/cavalier/probe-tangent-arc-contours.mjs').read_text().replace('../../test_portable/build/dev/javascript',str(target))
s+='\nconsole.error(JSON.stringify({timing:globalThis.auditTiming,slowPairs:globalThis.auditSlowPairs},null,2));\n'
(root/'scripts/cavalier/probe-tangent-performance.mjs').write_text(s)
