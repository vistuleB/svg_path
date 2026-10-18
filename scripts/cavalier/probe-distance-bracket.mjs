import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
const u=r=>{if(!r.isOk())throw r[0];return r[0]};
const arc=new g.Arc(new g.Point(0,0),new g.Point(1e7,1e7),0,false,true,new g.Point(10,0)),query=new g.Point(3,1);
const value=t=>{const p=u(g.segment_point(arc,t)),d=u(g.segment_derivative(arc,t));return (p.x-query.x)*d.x+(p.y-query.y)*d.y;};
let left=.29,right=.3,lv=value(left);const trace=[];
for(let iteration=0;iteration<100;iteration++){
 const piece=u(g.segment_between_inside(arc,left,right)),box=u(bounds.segment_bounding_box(piece)),diameter=box.max.x-box.min.x+box.max.y-box.min.y;
 const midpoint=left+(right-left)/2,v=value(midpoint);
 trace.push({iteration,left,right,width:right-left,midpoint,stationary_value:v,portion:piece,bounds:box,diameter,stagnated:midpoint===left||midpoint===right});
 if(v===0||diameter<=1e-9)break;
 if((lv<0)===(v<0)){left=midpoint;lv=v}else right=midpoint;
}
fs.writeFileSync(new URL('distance-bracket-trace.json',import.meta.url),JSON.stringify(trace,null,2)+'\n');
console.log(JSON.stringify(trace.filter((r,i)=>[0,10,20,30,40,50,99].includes(i)),null,2));
