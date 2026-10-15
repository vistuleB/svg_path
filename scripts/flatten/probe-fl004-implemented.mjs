// Verify the adopted fix and the explicit minimum-length policy separately.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as ct from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {polygonPath,errorDetails}=await import('./compare-arc-circle.mjs');
const call=JSON.parse(fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').split('\n')[4919]);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const a=polygonPath(call.input),b=polygonPath(call.arguments[0]),expected=polygonPath(call.result);
const ordinary=csg.intersection_path(a,b,new g.EvenOdd());
const result=unwrap(csg.intersection_path_with(a,b,new g.EvenOdd(),new csg.Options(1e-6,1e-9)));
const ps=[...call.input.edges,...call.arguments[0].edges].flatMap(e=>[e.start,e.end]);
const xmin=Math.min(...ps.map(p=>p.x)),xmax=Math.max(...ps.map(p=>p.x)),ymin=Math.min(...ps.map(p=>p.y)),ymax=Math.max(...ps.map(p=>p.y));
const mismatches=[];let checked=0,boundary=0;
for(let i=0;i<13;i++)for(let j=0;j<13;j++){
 const p=new g.Point(xmin+(xmax-xmin)*(i+.37)/13,ymin+(ymax-ymin)*(j+.61)/13);
 const actual=unwrap(ct.path_containment(p,result,new g.EvenOdd())),reference=unwrap(ct.path_containment(p,expected,new g.EvenOdd()));
 if(actual instanceof g.Boundary||reference instanceof g.Boundary){boundary++;continue;}
 checked++;if(actual.constructor!==reference.constructor)mismatches.push(p);
}
const actualArea=area.signed_path(result),expectedArea=area.signed_path(expected);
const report={defaultResult:ordinary.isOk()?{ok:true}:errorDetails(ordinary[0]),minimumLength:1e-9,actualArea,expectedArea,areaError:Math.abs(actualArea-expectedArea),checked,boundary,mismatches};
fs.writeFileSync(new URL('remaining-fl004-implemented.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
if(ordinary.isOk()||ordinary[0].constructor.name!=='RefinedBoundaryNotClosed'||mismatches.length||report.areaError>1e-6)process.exitCode=1;
