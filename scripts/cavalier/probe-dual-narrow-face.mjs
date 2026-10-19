import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as a from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const P=(x,y)=>new g.Point(x,y),L=(p,q)=>new g.Line(p,q);
const rows=[];
for(const size of [1e-3,1e-4,1e-5])for(const remote of [false,true]){
 const p=P(0,0),q=P(size,-size),segments=[L(p,P(1,0)),L(P(1,0),P(0,1)),L(P(0,1),p),new g.Arc(p,P(1,1),0,false,true,q),L(q,p)];
 if(remote)segments.push(L(P(3,0),P(3,1)));
 const start=performance.now(),built=a.build_with(toList(segments),1e-12,1e-12,0);
 if(!built.isOk()){rows.push({size,remote,buildError:built[0].constructor.name});continue;}
 const graph=built[0].graph,r=a.dual(graph);
 rows.push({size,remote,vertices:[...graph.vertices].length,edges:[...graph.edges].length,milliseconds:performance.now()-start,result:r.isOk()?{faces:[...r[0].faces].length}:r[0].constructor.name});
}
console.log(JSON.stringify(rows,null,2));
