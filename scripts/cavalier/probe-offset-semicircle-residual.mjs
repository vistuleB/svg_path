// Diagnostic only: preserve upstream semicircle intent with two quarter arcs.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]},P=(x,y)=>new g.Point(x,y);
const cases=JSON.parse(fs.readFileSync(new URL('./original-offset-specific-cases.json',import.meta.url)));
for(const id of ['CC01504','CC01508']){
 const c=cases.find(c=>c.id===id),rows=[];
 for(const split of [false,true]){
  const segments=c.input.vertices.flatMap((v,i)=>{
   const w=c.input.vertices[(i+1)%c.input.vertices.length],a=P(v[0],v[1]),b=P(w[0],w[1]);
   if(!v[2])return [new g.Line(a,b)];
   if(Math.abs(v[2])!==1)throw Error('Expected exact upstream semicircle');
   const r=Math.hypot(b.x-a.x,b.y-a.y)/2,R=P(r,r),arc=new g.Arc(a,R,0,false,v[2]>0,b);
   if(!split)return [arc];
   const mid=P((a.x+b.x)/2+Math.sign(v[2])*(b.y-a.y)/2,(a.y+b.y)/2-Math.sign(v[2])*(b.x-a.x)/2);
   return [new g.Arc(a,R,0,false,v[2]>0,mid),new g.Arc(mid,R,0,false,v[2]>0,b)];
  });
  const sub=ok(g.subpath_close(ok(g.subpath(toList(segments)))));
  const out=ok(off.path_with(new g.Path(toList([sub])),-c.offset,new off.Round(),new off.Butt(),off.default_options(),new off.SingleOffsetTrimming(true,new off.InBandTrimming())));
  rows.push({split,inputArcs:segments.filter(s=>s instanceof g.Arc).map(s=>({segment:s,centerData:ok(g.arc_center_data(s)),midpointCenterDistance:Math.hypot(ok(g.arc_center_data(s)).center.x-(s.start.x+s.end.x)/2,ok(g.arc_center_data(s)).center.y-(s.start.y+s.end.y)/2)})),output:[...out.subpaths].map(s=>({area:area.signed_subpath(s),length:ok(measure.subpath_length(s)),segments:[...g.subpath_segments(s)]}))});
 }
 console.log(JSON.stringify({id,rows}));
}
