import {pathToFileURL} from 'node:url';
const base=process.argv[2]??'/tmp/cavalier-endpoint-experiment';
const g=await import(pathToFileURL(`${base}/svg_path/svg_path.mjs`));
const ix=await import(pathToFileURL(`${base}/svg_path/svg_path/intersections.mjs`));
const a=new g.Arc(new g.Point(59.76247350201103,59.7377048577821),new g.Point(84.49938828627135,84.49938828627135),0,false,true,new g.Point(59.70692262458793,59.79322713698864));
const b=new g.Arc(new g.Point(59.76247342962466,59.73770478542024),new g.Point(85.20624291591454,85.20624291591454),0,false,false,new g.Point(59.70695115012889,59.79325542571751));
const options=ix.default_options();options.tolerance=5e-7;
const r=ix.segment_with(a,b,options);
if(!r.isOk())throw r[0];
console.log(JSON.stringify(Array.from(r[0],hit=>{
 const p=g.segment_point(a,hit.left_t)[0],q=g.segment_point(b,hit.right_t)[0];
 return {...hit,pair_distance:Math.hypot(p.x-q.x,p.y-q.y),left_distance:Math.hypot(p.x-hit.point.x,p.y-hit.point.y),right_distance:Math.hypot(q.x-hit.point.x,q.y-hit.point.y)};
}),null,2));
