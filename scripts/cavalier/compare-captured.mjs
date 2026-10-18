import fs from 'node:fs';
import {Worker,isMainThread,parentPort} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as ellipse from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as intr from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as contain from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]}, P=v=>new g.Point(v[0],v[1]);
const vals=s=>[...s.matchAll(/(?:x|y|bulge|min_x|min_y|max_x|max_y|seg1_t|seg2_t|t0|t1|t): (-?[\d.]+(?:e[+-]?\d+)?)/g)].map(m=>Number(m[1]));
const vec=s=>vals(s).slice(0,2),vertex=s=>vals(s).slice(0,3);
function seg(v,w){
 const p=P(v),q=P(w),b=v[2]??0;
 if(!b)return new g.Line(p,q);
 const chord=Math.hypot(w[0]-v[0],w[1]-v[1]);
 if(chord===0)throw {scope:'coincident arc endpoints'};
 const radius=chord*(1+b*b)/(4*Math.abs(b));
 return new g.Arc(p,new g.Point(radius,radius),0,Math.abs(b)>1,b>0,q);
}
function sub(p){
 const vs=p.vertices;
 if(!vs.length)throw {scope:'empty polyline without start coordinate'};
 if(vs.length===1)return g.subpath_empty(P(vs[0]));
 const ss=vs.slice(0,p.closed?vs.length:vs.length-1).map((v,i)=>seg(v,vs[(i+1)%vs.length]));
 const s=unwrap(g.subpath(toList(ss)));return p.closed?unwrap(g.subpath_close(s)):s;
}
const path=p=>new g.Path(toList([sub(p)]));
function properties(s,openZero=false){
 const b=unwrap(bounds.subpath_bounding_box(s));
 return {area:openZero?0:area.signed_subpath(s),length:unwrap(measure.subpath_length(s)),bounds:[b.min.x,b.min.y,b.max.x,b.max.y],closed:g.subpath_is_closed(s)};
}
function matchProps(actual,expected,abs=false){
 const owner=new Map();
 const compatible=(a,e)=>Math.abs((abs?Math.abs(a.area):a.area)-(abs?Math.abs(e.area):e.area))<=1e-4&&Math.abs(a.length-e.length)<=1e-4&&a.bounds.every((v,i)=>Math.abs(v-e.bounds[i])<=1e-4);
 function augment(i,seen=new Set()) {for(let j=0;j<expected.length;j++)if(!seen.has(j)&&compatible(actual[i],expected[j])){seen.add(j);if(!owner.has(j)||augment(owner.get(j),seen)){owner.set(j,i);return true}}return false}
 return actual.length===expected.length&&actual.every((_,i)=>augment(i));
}
const unique=points=>points.filter((p,i)=>!points.slice(0,i).some(q=>Math.hypot(p[0]-q[0],p[1]-q[1])<=1e-7));
const pointsFromDebug=s=>[...s.matchAll(/Vector2 \{ x: ([^,]+), y: ([^}]+) \}/g)].map(m=>[Number(m[1]),Number(m[2])]);
function comparePoints(actual,expected){
 actual=unique(actual);expected=unique(expected);const owners=new Map();
 function augment(i,seen=new Set()){for(let j=0;j<expected.length;j++)if(!seen.has(j)&&Math.hypot(actual[i][0]-expected[j][0],actual[i][1]-expected[j][1])<=1e-6){seen.add(j);if(!owners.has(j)||augment(owners.get(j),seen)){owners.set(j,i);return true}}return false}
 return {status:actual.length===expected.length&&actual.every((_,i)=>augment(i))?'match':'discrepancy',actual,expected};
}
function circle(center,r){if(!(r>0))throw {scope:'nonpositive circle radius'};const [x,y]=center;const vs=[[x+r,y,1],[x-r,y,1]];return [seg(vs[0],vs[1]),seg(vs[1],vs[0])];}
function compare(c){
 let phase='conversion';
 try {

  if(c.kind==='find_point_at_path_length'){
   const s=sub(c.input);phase='point-at-length';
   const r=measure.subpath_point_at_length(s,c.distance);
   if(c.result.startsWith('Err'))return {status:'scope',reason:'Upstream out-of-range result carries total length; native policy needs separate adaptation',native:r.isOk()?r[0]:r[0].constructor.name};
   const p=unwrap(r);return comparePoints([[p.x,p.y]],pointsFromDebug(c.result));
  }
  if(c.kind.startsWith('seg_')||c.kind==='dist_from_segment_start'){
   const v=vertex(c.v1),w=vertex(c.v2),s=seg(v,w);phase=c.kind;
   const scalar=(actual,expected)=>({status:Math.abs(actual-expected)<=1e-6?'match':'discrepancy',actual,expected});
   if(c.kind==='seg_length')return scalar(unwrap(measure.segment_length(s)),Number(c.result));
   if(c.kind==='seg_midpoint'){const p=unwrap(g.segment_point(s,.5));return comparePoints([[p.x,p.y]],pointsFromDebug(c.result));}
   if(c.kind==='seg_bounding_box'||c.kind==='seg_fast_approx_bounding_box'){
    const b=unwrap(bounds.segment_bounding_box(s)),actual=[b.min.x,b.min.y,b.max.x,b.max.y],expected=vals(c.result);
    if(c.kind==='seg_fast_approx_bounding_box')return {status:'scope',reason:'Upstream fast sagitta box is not an exact-bounds equality contract',actual,expected};
    return {status:actual.every((v,i)=>Math.abs(v-expected[i])<=1e-6)?'match':'discrepancy',actual,expected};
   }
   if(c.kind==='seg_arc_radius_and_center'){
    const ep=new ellipse.EndpointArcData(s.start,s.radius,s.x_axis_rotation,s.large_arc,s.sweep,s.end),a=unwrap(ellipse.endpoint_to_center(ep));
    const expectedRadius=Number(c.result.match(/^\(([^,]+)/)[1]),p=pointsFromDebug(c.result)[0];
    const actual=[a.radius.x,a.center.x,a.center.y],expected=[expectedRadius,...p];
    return {status:actual.every((v,i)=>Math.abs(v-expected[i])<=1e-6)?'match':'discrepancy',actual,expected};
   }
   if(c.kind==='seg_closest_point'){
    const p=unwrap(distance.segment_projection(P(vec(c.point)),s)).point;
    return comparePoints([[p.x,p.y]],pointsFromDebug(c.result));
   }
   if(c.kind==='seg_distance_is_greater_than'){
    const actual=unwrap(distance.segment_distance(P(vec(c.point)),s))>Math.abs(Number(c.distance)),expected=c.result==='true';
    return {status:actual===expected?'match':'discrepancy',actual,expected};
   }
   const p=P(vec(c.point??c.point_on_seg)),projection=unwrap(distance.segment_projection(p,s));
   if(c.kind==='dist_from_segment_start')return scalar(unwrap(measure.segment_length(unwrap(g.segment_between(s,0,projection.at)))),Number(c.result));
   if(c.kind==='seg_tangent_vector'){
    const d=unwrap(g.segment_derivative(s,projection.at)),e=pointsFromDebug(c.result)[0];
    const n=Math.hypot(d.x,d.y),m=Math.hypot(...e);
    return {...comparePoints([[d.x/n,d.y/n]],[[e[0]/m,e[1]/m]]),comparison:'direction-only; upstream radius-scaled magnitude is not native parameter derivative'};
   }
   if(c.kind==='seg_split_at_point'){
    const vv=[...c.result.matchAll(/PlineVertex \{ x: ([^,]+), y: ([^,]+), bulge: ([^}]+) \}/g)].map(m=>m.slice(1).map(Number));
    const expected=[seg(vv[0],vv[1]),seg(vv[1],w)],actual=unwrap(g.segment_split(s,projection.at));
    const as=[],es=[];
    for(let i=0;i<2;i++)for(const t of [0,.25,.5,.75,1]){let a=unwrap(g.segment_point(actual[i],t)),e=unwrap(g.segment_point(expected[i],t));as.push([a.x,a.y]);es.push([e.x,e.y]);}
    return {...comparePoints(as,es),comparison:'sampled split geometry; bulge/vertex representation not compared'};
   }
  }
  if(c.helper_only)return {status:'helper-only',reason:'Property calls used by upstream test helpers; not independent assertion adaptation.'};
  if(c.kind==='offset'||c.kind==='shape_offset'){
   const p=c.kind==='offset'?path(c.input):new g.Path(toList(c.inputs.filter(p=>p.vertices.length).map(sub)));
   phase='offset';const r=unwrap(off.path(p,-c.offset,new off.Round(),new off.Butt()));phase='properties';
   const actual=Array.from(r.subpaths).map(s=>properties(s,c.kind==='offset'&&!c.input.closed));
   return {status:matchProps(actual,c.result)?'match':'discrepancy',actual,expected:c.result,policy:c.options??'ShapeOffsetOptions::default'};
  }
  if(c.kind==='boolean'){
   if(!c.input.closed||!c.other.closed)throw {scope:'Boolean requires closed inputs'};
   const a=path(c.input),b=path(c.other);phase='boolean';
   const fn={Or:csg.union_path,And:csg.intersection_path,Not:csg.difference_path,Xor:csg.symmetric_difference_path}[c.operation];
   const r=unwrap(fn(a,b,new g.Nonzero()));phase='properties';
   const actual=Array.from(r.subpaths).map(s=>properties(s));const expected=[...c.positive,...c.negative];
   return {status:matchProps(actual,expected,true)?'match':'discrepancy',actual,expected};
  }
  if(['area','path_length','extents','winding_number'].includes(c.kind)){
   if(c.kind==='area'&&!c.input.closed)throw {scope:'Upstream open-polyline area is zero; native signed area integrates open segments'};
   if(c.kind==='winding_number'&&!c.input.closed)throw {scope:'Upstream open-polyline winding is zero; native winding implicitly closes'};
   const s=sub(c.input);phase=c.kind;
   if(c.kind==='winding_number'){
    const r=unwrap(contain.path_winding(P(c.point),new g.Path(toList([s]))));
    if(r instanceof g.BoundaryWinding)return {status:'contract-difference',reason:'Native returns boundary classification instead of an integer winding',expected:c.result};
    return {status:r[0]===c.result?'match':'discrepancy',actual:r[0],expected:c.result};
   }
   if(c.kind==='extents'){
    if(c.result==='None')throw {scope:'No upstream bounding box'};
    const b=unwrap(bounds.subpath_bounding_box(s)),actual=[b.min.x,b.min.y,b.max.x,b.max.y],expected=vals(c.result);
    return {status:actual.every((v,i)=>Math.abs(v-expected[i])<=1e-6)?'match':'discrepancy',actual,expected};
   }
   const actual=c.kind==='area'?area.signed_subpath(s):unwrap(measure.subpath_length(s)),expected=Number(c.result);
   return {status:Math.abs(actual-expected)<=1e-6?'match':'discrepancy',actual,expected};
  }
  if(c.kind==='contains'){
   if(!c.input.closed||!c.other.closed)throw {scope:'whole-polyline containment invalid-input policies differ'};
   const a=path(c.input),b=path(c.other);phase='contains';let actual;
   const r=intr.path(a,b);
   if(!r.isOk()){
    if(r[0].constructor.name==='OverlappingSegments')actual='Intersected';else throw r[0];
   }else if(Array.from(r[0]).length)actual='Intersected';
   if(!actual){
    const inside=(p,q)=>unwrap(contain.path_containment(P(p.vertices[0]),q,new g.Nonzero()));
    const ab=inside(c.input,b),ba=inside(c.other,a);
    actual=ab instanceof g.Inside?'Pline1InsidePline2':ba instanceof g.Inside?'Pline2InsidePline1':'Disjoint';
   }
   return {status:actual===c.result?'match':'discrepancy',actual,expected:c.result,derived:true};
  }
  if(c.kind==='line_circle_intr'){
   const ss=circle(vec(c.circle_center),Number(c.radius)),p=vec(c.p0),q=vec(c.p1),d=[q[0]-p[0],q[1]-p[1]];
   phase='intersections';const actual=ss.flatMap(s=>Array.from(unwrap(contain.segment_ray_crossings(s,P(p),P(d)))).map(t=>[p[0]+t[1]*d[0],p[1]+t[1]*d[1]]));
   const expected=vals(c.result).map(t=>[p[0]+t*d[0],p[1]+t*d[1]]);return comparePoints(actual,expected);
  }
  let left,right,expected;
  if(c.kind==='line_line_intr'){
   left=[seg(vec(c.v1),vec(c.v2))];right=[seg(vec(c.u1),vec(c.u2))];
   expected=c.result.startsWith('TrueIntersect')?(()=>{const t=vals(c.result)[0],p=vec(c.v1),q=vec(c.v2);return [[p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])]]})():[];
  }else if(c.kind==='pline_seg_intr'){
   left=[seg(vertex(c.v1),vertex(c.v2))];right=[seg(vertex(c.u1),vertex(c.u2))];expected=pointsFromDebug(c.result);
  }else if(c.kind==='circle_circle_intr'){
   left=circle(vec(c.center1),Number(c.radius1));right=circle(vec(c.center2),Number(c.radius2));expected=pointsFromDebug(c.result);
  }else return {status:'scope',reason:'Unmapped captured operation'};
  if(c.result.startsWith('Overlapping'))return {status:'contract-difference',reason:'Upstream overlap variant needs encounters interval adaptation; point-only query is insufficient'};
  phase='intersections';const actual=left.flatMap(a=>right.flatMap(b=>Array.from(unwrap(intr.segment(a,b))).map(x=>[x.point.x,x.point.y])));
  return comparePoints(actual,expected);
 }catch(e){return e.scope?{status:'scope',reason:e.scope}:{status:'error',phase,error:{type:e.constructor?.name,...e}};}
}
if(!isMainThread)parentPort.on('message',c=>parentPort.postMessage(compare(c)));
else {
 const cases=JSON.parse(fs.readFileSync(new URL(process.env.CAVALIER_CASES??'captured-cases.json',import.meta.url)));
 const out=new URL(process.env.CAVALIER_RESULTS??'captured-results.jsonl',import.meta.url);
 const done=new Set(fs.existsSync(out)?fs.readFileSync(out,'utf8').trim().split('\n').filter(Boolean).map(l=>JSON.parse(l).id):[]);
 const pending=cases.filter(c=>!done.has(c.id));let n=done.size;
 async function runner(){let worker;
  function start(){worker=new Worker(new URL(import.meta.url));}start();
  while(pending.length){const c=pending.shift(),t=Date.now();
   const result=await new Promise(resolve=>{
    const finish=r=>{clearTimeout(timer);worker.removeAllListeners('message');worker.removeAllListeners('error');resolve(r)};
    const timer=setTimeout(()=>{worker.terminate();finish({status:'timeout',seconds:Number(process.env.CAVALIER_TIMEOUT_MS??10000)/1000});start()},Number(process.env.CAVALIER_TIMEOUT_MS??10000));
    worker.once('message',finish);worker.once('error',e=>{finish({status:'harness-error',error:String(e)});start()});worker.postMessage(c);
   });
   fs.appendFileSync(out,JSON.stringify({id:c.id,kind:c.kind,binary:c.binary,test:c.test,milliseconds:Date.now()-t,...result})+'\n');
   console.log(++n,'/',cases.length,c.id,c.kind,result.status);
  }await worker.terminate();
 }
 await Promise.all(Array.from({length:Number(process.env.CAVALIER_WORKERS??4)},()=>runner()));
}
