"""Copy the generated JS build to /tmp and add observational tracing only."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-cyclic-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs'
s=p.read_text().replace('function circle_sample_for_oriented_edge(', 'function original_circle_sample_for_oriented_edge(',1)
s+='''
function circle_sample_for_oriented_edge(edges, oriented, vertex, vertexId, radius, tolerance) {
 const result=original_circle_sample_for_oriented_edge(edges,oriented,vertex,vertexId,radius,tolerance);
 if(!result.isOk() && result[0] instanceof InternalCyclicOrderCircleIntersectionFailed){
  const edge=edge_for_oriented_edge(edges,oriented)[0];
  const segment=segment_relative_to(outward_oriented_edge_segment(edge,oriented),vertex);
  const residualTolerance=tolerance*(2*radius+tolerance);
  const roots=$containment.segment_crossings_with(segment,p=>$point.dot(p,p)-radius*radius,new $svg_path.CrossingOptions(100,residualTolerance,100));
  globalThis.cyclicTrace??=[];
  globalThis.cyclicTrace.push({vertexId,edgeId:edge.id,radius,tolerance,residualTolerance,segment:{type:segment.constructor.name,...segment},startResidual:$point.dot(segment.start,segment.start)-radius*radius,endResidual:$point.dot(segment.end,segment.end)-radius*radius,roots:roots.isOk()?Array.from(roots[0]):null});
 }
 return result;
}
'''
p.write_text(s)
print(target)
