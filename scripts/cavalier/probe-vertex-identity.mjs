import * as g from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path.mjs';
import * as a from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/arrangement.mjs';
import {toList} from '/tmp/cavalier-near-tangent-offset-trace/prelude.mjs';
const p=(x,y)=>new g.Point(x,y), A=p(0,0);
const segments=[new g.Line(A,p(0,10)),new g.Line(p(2.6,0),p(2.6,20)),new g.Line(p(-2.36,0),p(-2.36,30)),new g.Line(A,p(0,-10)),new g.Line(A,p(10,-10))];
let graph=a.empty();
for(const s of segments){
 const r=a.insert_atomic_segment(graph,s,2,.01);if(!r.isOk())throw r[0];graph=r[0];
 console.log(JSON.stringify({owners:[...graph.vertices].filter(v=>[...v.endpoint_samples].some(p=>p.x===0&&p.y===0)).map(v=>({id:v.id,point:v.point}))}));
}
const r=a.build_with(toList(segments),2,.01,0);
console.log(JSON.stringify({build:r.isOk()?'Ok':r[0].constructor.name}));
