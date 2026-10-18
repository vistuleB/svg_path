import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ar from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import * as contain from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const encode=r=>r.isOk()?{ok:true}:{error:{type:r[0].constructor.name,...r[0]}};
const p=(x,y)=>new g.Point(x,y);
const rows=[];
for(const length of [2e-6,2.5e-6,3e-6,3.1e-6,4e-6,1e-5]){
 const a=new g.Line(p(0,0),p(1,0)),b=new g.Line(p(0,0),p(0,length));
 const radius=.8*length,tolerance=1e-6*(2*radius+1e-6);
 const crossing=contain.segment_crossings_with(a,q=>q.x*q.x+q.y*q.y-radius*radius,new g.CrossingOptions(100,tolerance,100));
 rows.push({length,radius,residual_tolerance:tolerance,origin_residual:-radius*radius,roots:crossing.isOk()?Array.from(crossing[0]):encode(crossing),build:encode(ar.build_with(toList([a,b]),1e-6,1e-8,0))});
}
console.log(JSON.stringify(rows,null,2));
