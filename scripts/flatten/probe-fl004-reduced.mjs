// Isolate tolerance-sized reversed overlap correspondences on crossing lines.
import fs from 'node:fs';
const base=process.env.PROBE_RUNTIME??'../../test_portable/build/dev/javascript/';
const g=await import(base+'svg_path/svg_path.mjs');
const ix=await import(base+'svg_path/svg_path/intersections.mjs');
const ov=await import(base+'svg_path/svg_path/overlaps.mjs');
const arr=await import(base+'svg_path/svg_path/arrangement.mjs');
const {toList}=await import(base+'prelude.mjs');
const left=new g.Line(new g.Point(0,0),new g.Point(1,1));
const right=new g.Line(new g.Point(-2e-7,2e-7),new g.Point(1,1-3e-6));
const query=r=>r.isOk()?{ok:true,values:[...r[0]]}:{ok:false,error:r[0].constructor.name};
const rows=[];
for(const tolerance of [1e-6,1e-7,1e-8])for(const reverse of [false,true]){
 const segs=reverse?[right,left]:[left,right];
 const build=arr.build_with(toList(segs),tolerance,1e-9,0);
 const graph=build.isOk()?{vertices:[...build[0].graph.vertices],edges:[...build[0].graph.edges]}:{error:build[0].constructor.name};
 rows.push({tolerance,reverse,left:segs[0],right:segs[1],overlaps:query(ov.segment_with(...segs,tolerance/2)),intersections:query(ix.segment_with(...segs,Object.assign(ix.default_options(),{tolerance:tolerance/2}))),graph});
}
fs.writeFileSync(new URL(process.env.PROBE_OUTPUT??'remaining-fl004-reduced.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
for(const r of rows)console.log(JSON.stringify({tolerance:r.tolerance,reverse:r.reverse,overlaps:r.overlaps,intersections:r.intersections,vertices:r.graph.vertices?.length,edges:r.graph.edges?.length}));
