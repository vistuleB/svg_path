from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2];target=Path('/tmp/cavalier-dual-replay')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
for name in ['dual_sweep_intersections','dual_pair_line','dual_sweep_edge_hits','dual_check_hit_separation']:
 s=s.replace('function '+name+'(', 'function original_'+name+'(',1)
s+='''
function dual_pair_line(edges,walk,seed) {
 globalThis.auditWalk=walk;
 (globalThis.auditWalkEdges??={})[walk]=[...edges].filter(e=>e.left_walk===walk||e.right_walk===walk);
 return original_dual_pair_line(edges,walk,seed);
}
function dual_sweep_edge_hits(...args) {
 const r=original_dual_sweep_edge_hits(...args);
 if(!r.isOk())globalThis.auditReason='edge-hit';return r;
}
function dual_check_hit_separation(...args) {
 const r=original_dual_check_hit_separation(...args);
 if(!r.isOk())globalThis.auditReason='hit-separation';return r;
}
function dual_sweep_intersections(edges,vertices,line,tolerance) {
 globalThis.auditReason='vertex-proximity';
 const r=original_dual_sweep_intersections(edges,vertices,line,tolerance);
 const key=String(globalThis.auditWalk??'exterior')+':'+(r.isOk()?'accepted':globalThis.auditReason);
 const counts=(globalThis.auditSweepCounts??={});counts[key]=(counts[key]??0)+1;
 if(!r.isOk() && globalThis.auditReason==='vertex-proximity') {
  const close=[...vertices].filter(v=>Math.abs(dual_signed_line_distance(v.point,line))<=tolerance).map(v=>({id:v.id,distance:Math.abs(dual_signed_line_distance(v.point,line))}));
  const samples=(globalThis.auditSweepSamples??=[]);if(samples.length<10)samples.push({walk:globalThis.auditWalk,line,tolerance,close});
 }
 return r;
}
''';p.write_text(s)
