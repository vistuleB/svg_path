import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const rows=[];
for(const chord of [1,1e-3,1e-5,1e-7,1e-8,1e-9]){
 const a=new g.Arc(new g.Point(0,0),new g.Point(1,1),0,false,true,new g.Point(chord,0));
 for(const reverse of [false,true]){
  const b=reverse?g.segment_reverse(a):a,t=performance.now(),r=ix.segment(a,b);
  rows.push({chord,reverse,milliseconds:performance.now()-t,result:r.isOk()?{hits:[...r[0]]}:{error:r[0].constructor.name}});
 }
}
console.log(JSON.stringify(rows,null,2));
