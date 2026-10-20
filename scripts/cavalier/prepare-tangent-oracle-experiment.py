"""Diagnostic oracle seeding in a copied build, not a proposed implementation."""
import json,math,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2];p=root/'scripts/cavalier'
target=Path('/tmp/cavalier-tangent-oracle-experiment')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
arcs=json.loads((p/'tangent-timeout-original-pair.json').read_text())
oracle=json.loads((p/'tangent-timeout-circle-oracle.json').read_text())
roots=[[float(v) for v in point] for point in oracle['roots']]
hits=[]
for x,y in roots:
 hits.append([(math.pi-math.atan2(y-10,x-12))/(math.pi/2),-math.atan2(y-12,x-10)/(math.pi/2),x,y])
f=target/'svg_path/svg_path/intersections.mjs';s=f.read_text();needle='function curve_curve_intersections(';assert s.count(needle)==1;s=s.replace(needle,'function original_curve_curve_intersections(',1)
s+='''
function curve_curve_intersections(left,right,options) {
 const pair=%s, hits=%s;
 const key=s=>JSON.stringify([s.start.x,s.start.y,s.end.x,s.end.y,s.radius?.x,s.radius?.y,s.x_axis_rotation,s.large_arc,s.sweep]);
 if(key(left)===key(pair[0]) && key(right)===key(pair[1])) {
   console.error('ORACLE_PAIR_REPLACED');
   return new Ok(toList(hits.map(h=>new SegmentIntersection(h[0],h[1],new Point(h[2],h[3])))));
 }
 return original_curve_curve_intersections(left,right,options);
}
'''%(json.dumps(arcs),json.dumps(hits))
f.write_text(s)
(p/'tangent-oracle-seeded-hits.json').write_text(json.dumps(hits,indent=2)+'\n')
