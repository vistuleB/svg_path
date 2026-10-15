// Analytic rotation/scale/operand-order checks for the FL005 line/ellipse path.
// Build test_portable for JavaScript first. No timing assertions.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
const rows=[];
for(const angle of [0,53.13010235415598,137,-75]){
 for(const scale of [0.001,1,1000]){
  for(const offset of [0,1e6]){
   const radians=angle*Math.PI/180,c=Math.cos(radians),s=Math.sin(radians);
   const p=(x,y)=>new g.Point(offset+scale*(c*x-s*y),-2*offset+scale*(s*x+c*y));
   const line=new g.Line(p(0,10),p(10,0));
   const original=new g.Arc(p(4,0),new g.Point(4*scale,2*scale),angle,false,true,p(0,2));
   for(const reversed of [false,true]){
    const arc=reversed?g.segment_reverse(original):original;
    for(const swapped of [false,true]){
     const a=swapped?arc:line,b=swapped?line:arc;
     const r=distance.segment_segment_closest_pair(a,b);
     assert(r.isOk(),JSON.stringify(r));
     const hit=r[0],expected=scale*(10-Math.sqrt(20))/Math.sqrt(2);
     const error=Math.abs(hit.distance-expected);
     assert(error<Math.max(1e-8,scale*1e-8),JSON.stringify({angle,scale,offset,reversed,swapped,error}));
     for(const [segment,t,witness] of [[a,hit.left_at,hit.left_point],[b,hit.right_at,hit.right_point]]){
      assert(t>=0&&t<=1);const at=g.segment_point(segment,t);assert(at.isOk());assert.deepEqual(at[0],witness);
     }
     rows.push({angle,scale,offset,reversed,swapped,distance:hit.distance,expected,error});
    }
   }
  }
 }
}
fs.writeFileSync(new URL('remaining-fl005-transform-checks.json',import.meta.url),JSON.stringify({description:'Uncommitted FL005 line/arc implementation atop 3.1.3',rows},null,2)+'\n');
console.log(`${rows.length} analytic checks passed; maximum absolute error ${Math.max(...rows.map(x=>x.error))}`);
