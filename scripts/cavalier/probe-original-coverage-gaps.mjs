// Public geometric checks derived from originally uncaptured upstream tests.
// These do not reproduce upstream private routing or Rust representation contracts.
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as intr from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as enc from '../../test_portable/build/dev/javascript/svg_path/svg_path/encounters.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]},p=(x,y)=>new g.Point(x,y);
const sub=ss=>ok(g.subpath(toList(ss))),line=(a,b)=>new g.Line(a,b);
function check(test,variant,fn){try{const r=fn();console.log(JSON.stringify({test,variant,...r}))}catch(e){console.log(JSON.stringify({test,variant,status:'error',error:{type:e.constructor?.name,...e}}))}}
for(const scale of [.001,1,1000]){
 check('small_arc_sweep_excludes_opposite_point_at_different_scales',scale,()=>{
  const center=p(27.4604,13.6769),scaleP=([x,y])=>p(center.x+(x-center.x)*scale,center.y+(y-center.y)*scale);
  const a=scaleP([27.455462563050666,13.676111510068951]),b=scaleP([27.45546524477275,13.676094896995954]),q=scaleP([27.465336109592272,13.67769680169451]);
  const radius=Math.hypot(a.x-center.x,a.y-center.y);const arc=new g.Arc(a,p(radius,radius),0,false,true,b);
  const d=ok(distance.segment_distance(q,arc));return {status:d>1e-5*scale?'match':'discrepancy',distance:d};
 });
 const arc=new g.Arc(p(scale,0),p(scale,scale),0,false,true,p(0,scale)),eps=1e-5*scale;
 for(const [name,q,expected] of [['start-in',p(scale,-.5*eps),true],['start-out',p(scale,-2*eps),false],['end-in',p(-.5*eps,scale),true],['end-out',p(-2*eps,scale),false]])check('arc_sweep_uses_position_tolerance_at_both_boundaries',`${scale}/${name}`,()=>{const d=ok(distance.segment_distance(q,arc));return {status:(d<=eps)===expected?'match':'discrepancy',distance:d,epsilon:eps}});
}
const half=new g.Arc(p(0,0),p(1,1),0,false,true,p(2,0));
for(const name of ['empty_polyline','single_vertex','circle_no_intersects'])check(name,'public-self-intersections',()=>{
 const s=name==='circle_no_intersects'?ok(g.subpath_close(sub([half,new g.Arc(p(2,0),p(1,1),0,false,true,p(0,0))]))):g.subpath_empty(p(0,0));
 const n=[...ok(intr.subpath_self(s))].length;return {status:n===0?'match':'discrepancy',count:n};
});
check('half_circle_overlapping_self','segment-encounters',()=>{const r=ok(enc.segment(half,g.segment_reverse(half)));return {status:[...r.overlaps].length===1&&[...r.intersections].length===0?'match':'discrepancy',overlaps:[...r.overlaps],intersections:[...r.intersections]}});
check('normal_raw_offsets_have_no_invalid_segments','public-untrimmed',()=>{
 const r=ok(off.subpath_untrimmed(sub([line(p(0,0),p(10,0)),line(p(10,0),p(10,10))]),1,new off.Round()));
 const ss=[...g.subpath_segments(r)],length=ok(measure.subpath_length(r));return {status:ss.length===3&&Math.abs(length-(20+Math.PI/2))<1e-9?'match':'discrepancy',segments:ss,length};
});
for(const angle of [1e-12,1e-8,1e-4,Math.PI/2,Math.PI-1e-8,Math.PI])for(const sign of [-1,1])check('round_join_bulge_matches_sweep_and_offset_direction',`${angle}/${sign}`,()=>{
 // Two unit lines with an outer join. Compare total raw length, not bulge storage.
 const r=ok(off.subpath_untrimmed(sub([line(p(-1,0),p(0,0)),line(p(0,0),p(Math.cos(angle),sign*Math.sin(angle)))]),sign,new off.Round()));
 const length=ok(measure.subpath_length(r));return {status:Math.abs(length-(2+angle))<1e-8?'match':'discrepancy',length,expected:2+angle};
});
