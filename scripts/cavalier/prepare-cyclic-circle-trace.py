from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-cyclic-circle-trace')
shutil.copytree(root/'scripts/cavalier/probe/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs'
s=p.read_text().replace('function circle_sample_for_oriented_edge(', 'function original_circle_sample_for_oriented_edge(',1)
s+='''
function circle_sample_for_oriented_edge(edges,oriented,vertex,id,radius,tolerance) {
 const r=original_circle_sample_for_oriented_edge(edges,oriented,vertex,id,radius,tolerance);
 if(!r.isOk()) {
  const edge=[...edges].find(e=>e.id===oriented.edge_id);
  const segment=segment_relative_to(outward_oriented_edge_segment(edge,oriented),vertex);
  const rows=(globalThis.auditCircleFailures??=[]);
  if(rows.length<300)rows.push({vertex,id,radius,tolerance,oriented,edge,segment,incident:[...edges].filter(e=>e.start_vertex===id||e.end_vertex===id),error:{type:r[0].constructor.name,...r[0]}});
 }
 return r;
}
'''
p.write_text(s)
