import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {Worker,isMainThread,parentPort,workerData} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as intersections from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as containment from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import {toList as fromArray} from '../../test_portable/build/dev/javascript/prelude.mjs';
import * as affine from '../../test_portable/build/dev/javascript/svg_path/svg_path/affine.mjs';
import * as transform from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as ellipse from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import * as ph from '../../test_portable/build/dev/javascript/svg_path/svg_path/point.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
const batch=process.env.FLATTEN_BATCH??'arc-circle';
if(!['arc-circle','arc-extra','linear','primitives','polygons','chains','residual'].includes(batch)) throw Error('Invalid batch');
const point=p=>new g.Point(p.x,p.y);
const unwrap=r=>{if(!r.isOk()) throw {geometryError:r[0].constructor.name,details:r[0]};return r[0];};
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const tolerance=1e-6; // Upstream DP_TOL; diagnostic comparison, not our accuracy contract.
function pieces(shape) {
 if(shape.type==='segment') return [new g.Line(point(shape.start),point(shape.end))];
 if(['polygon','face','multiline'].includes(shape.type)) return shape.edges.flatMap(pieces);
 if(shape.type==='box') {
  const {xmin:x0,ymin:y0,xmax:x1,ymax:y1}=shape;
  const ps=[{x:x0,y:y0},{x:x1,y:y0},{x:x1,y:y1},{x:x0,y:y1}];
  return ps.map((p,i)=>new g.Line(point(p),point(ps[(i+1)%4])));
 }
 if(!['arc','circle'].includes(shape.type)) throw {scope:'unsupported-shape',shape:shape.type};
 if(!(shape.radius>0)) throw {scope:'zero-radius-circle-contract',radius:shape.radius};
 const sweep=shape.type==='circle'?2*Math.PI:shape.sweep;
 if(!(sweep>0)) throw {scope:'zero-sweep-arc-contract'};
 const angle=shape.type==='circle'?0:shape.startAngle;
 const direction=shape.type==='circle'||shape.ccw?1:-1;
 const count=Math.ceil(sweep/(Math.PI/2));
 const at=t=>new g.Point(shape.center.x+shape.radius*Math.cos(angle+direction*sweep*t),shape.center.y+shape.radius*Math.sin(angle+direction*sweep*t));
 const points=Array.from({length:count+1},(_,i)=>at(i/count));
 if(shape.type==='arc'){points[0]=point(shape.start);points[count]=point(shape.end);}
 else points[count]=points[0];
 return points.slice(0,-1).map((p,i)=>new g.Arc(p,new g.Point(shape.radius,shape.radius),0,false,direction>0,points[i+1]));
}
const unique=ps=>ps.filter((p,i)=>!ps.slice(0,i).some(q=>dist(p,q)<=tolerance));
function sameSupport(a,b) {
 if(a.type==='segment'&&b.type==='segment') return true; // Only used when native solver explicitly reports OverlappingSegments.
 return ['arc','circle'].includes(a.type)&&['arc','circle'].includes(b.type)
  && a.radius===b.radius&&a.center.x===b.center.x&&a.center.y===b.center.y;
}
function matchingPoints(a,b) {
 const owners=new Map();
 function match(i,seen=new Set()) {
  for(let j=0;j<b.length;j++) if(!seen.has(j)&&dist(a[i],b[j])<=tolerance) {
   seen.add(j);if(!owners.has(j)||match(owners.get(j),seen)){owners.set(j,i);return true;}
  }
  return false;
 }
 return a.length===b.length&&a.every((_,i)=>match(i));
}
const polygonPath=s=>new g.Path(fromArray(s.faces.map(f=>unwrap(g.subpath(fromArray(f.flatMap(pieces)))))));
let phase='comparison';
const errorDetails=e=>e&&typeof e==='object'?{type:e.constructor.name,...Object.fromEntries(Object.entries(e).map(([k,v])=>[k,errorDetails(v)]))}:e;
function compare(c) {
 const b=c.arguments[0];
 const compared=(value,reference=c.result)=>{
  const numbers=v=>typeof v==='number'?[v]:Array.isArray(v)?v.flatMap(numbers):v&&typeof v==='object'?Object.entries(v).filter(([k])=>k!=='type').flatMap(([,v])=>numbers(v)):[];
  const xs=numbers(value),ys=numbers(reference);
  const error=xs.length===ys.length?Math.max(0,...xs.map((x,i)=>Math.abs(x-ys[i]))):Infinity;
  return {status:typeof value==='boolean'?(value===reference?'match':'needs-investigation'):(error<=tolerance?'match':'needs-investigation'),value,reference,error};
 };
 const am=m=>affine.matrix(m.a,m.b,m.c,m.d,m.tx,m.ty);
 const tm=m=>transform.from_tuple(affine.to_tuple(m));
 const scope=reason=>({status:'scope-difference',reason});
 if(c.operation.startsWith('relation:')) return scope('No DE-9IM or whole-shape topological relation predicate API; do not substitute boundary intersection for filled-set relations.');
 if(c.operation==='algorithm:shape2planarSet') {
  if(c.input.type!=='point'||b.type!=='planarset') return scope('Shape/set combination not adapted');
  const value=Math.min(...b.shapes.flatMap(pieces).map(s=>unwrap(distance.segment_distance(point(c.input),s))));
  return compared(value,c.result[0]);
 }
 if(c.operation.startsWith('algorithm:')&&c.operation!=='algorithm:ray_shoot') {
  const operation=c.operation.slice(10),fn={unify:csg.union_path,subtract:csg.difference_path,intersect:csg.intersection_path}[operation];
  if(!fn) return scope('Clipping lists or paired intersection ordering require a separate adapter.');
  if(c.thrown) return scope('Upstream operation throws; retained as an upstream failure-contract fixture.');
  phase='adapt-left-input';const left=polygonPath(c.input);
  phase='adapt-right-input';const right=polygonPath(b);
  phase='native-boolean-query';const actual=unwrap(fn(left,right,new g.EvenOdd()));
  phase='adapt-upstream-output';const expected=polygonPath(c.result);
  phase='compare-output-geometry';
  const actualArea=Math.abs(area.signed_path(actual)),expectedArea=Math.abs(area.signed_path(expected));
  const samples=pieces(c.input).concat(pieces(b)).map(s=>unwrap(bounds.segment_bounding_box(s)));
  const min={x:Math.min(...samples.map(s=>s.min.x)),y:Math.min(...samples.map(s=>s.min.y))},max={x:Math.max(...samples.map(s=>s.max.x)),y:Math.max(...samples.map(s=>s.max.y))};
  const mismatches=[];let checked=0,boundary=0;
  for(let i=0;i<13;i++) for(let j=0;j<13;j++) {
   const p=new g.Point(min.x+(max.x-min.x)*(i+.37)/13,min.y+(max.y-min.y)*(j+.61)/13);
   const av=unwrap(containment.path_containment(p,actual,new g.EvenOdd())),ev=unwrap(containment.path_containment(p,expected,new g.EvenOdd()));
   if(av instanceof g.Boundary||ev instanceof g.Boundary){boundary++;continue;}
   checked++;if(av.constructor!==ev.constructor) mismatches.push(p);
  }
  const areaError=Math.abs(actualArea-expectedArea),areaTolerance=1e-6*Math.max(1,expectedArea);
  return {status:!mismatches.length&&areaError<=areaTolerance?'sampled-geometry-match':'needs-investigation',actualArea,expectedArea,areaError,areaTolerance,checked,boundary,mismatches};
 }
 if(c.input.type==='polygon'&&(c.operation==='contains'||c.operation==='algorithm:ray_shoot')) {
  if(b.type!=='point') return scope('Shape inclusion requires a whole-shape predicate, not point sampling.');
  const value=unwrap(containment.path_containment(point(b),polygonPath(c.input),new g.EvenOdd()));
  return compared(c.operation==='contains'?!(value instanceof g.Outside):value instanceof g.Outside?0:value instanceof g.Inside?1:2);
 }
 if(c.input.type==='polygon'&&c.operation==='area') return compared(Math.abs(area.signed_path(polygonPath(c.input))));
 if(c.input.type==='polygon'&&c.operation==='intersect'&&b.type==='point') return scope('Point/polygon set inclusion differs from boundary intersection.');
 if(c.thrown) {
  if(c.input.type==='vector'&&c.operation==='normalize') {
   const result=ph.normalize(point(c.input));
   return {status:!result.isOk()?'match':'needs-investigation',reason:'Both reject zero-vector normalization; Result error vs exception.'};
  }
  return scope('Dynamic argument validation/exception has no corresponding typed call.');
 }
 if(c.input.type==='matrix') {
  const m=am(c.input);let result;
  if(c.operation==='transform') return compared(affine.point(m,b[0],b[1]));
  if(c.operation==='translate') result=affine.multiply(m,affine.translate(typeof b==='number'?b:b.x,typeof b==='number'?c.arguments[1]:b.y));
  if(c.operation==='rotate') result=affine.multiply(m,affine.about_point(affine.rotate(b*180/Math.PI),c.arguments[1]??0,c.arguments[2]??0));
  if(c.operation==='scale') result=affine.multiply(m,affine.scale_xy(b,c.arguments[1]));
  if(c.operation==='multiply') result=affine.multiply(m,am(b));
  return result?compared(affine.to_tuple(result),[c.result.a,c.result.b,c.result.c,c.result.d,c.result.tx,c.result.ty]):scope('No matrix operation adapter');
 }
 if(['point','vector'].includes(c.input.type)) {
  const p=point(c.input);let value;
  if(['dot','cross','add','subtract'].includes(c.operation)) value=ph[c.operation](p,point(b));
  if(c.operation==='multiply') value=ph.scale(p,b);
  if(c.operation==='invert') value=ph.negate(p);
  if(c.operation==='normalize') value=unwrap(ph.normalize(p));
  if(c.operation==='length'||c.operation==='perimeter') value=ph.norm(p);
  if(c.operation==='slope') value=ph.heading(p)*Math.PI/180;
  if(c.operation==='angleTo') value=ph.clockwise_aperture(p,point(b))*Math.PI/180;
  if(c.operation==='projectionOn'&&c.input.type==='vector') value=unwrap(ph.project(p,point(b)));
  if(c.operation==='translate') value=ph.add(p,new g.Point(typeof b==='number'?b:b.x,typeof b==='number'?c.arguments[1]:b.y));
  if(c.operation==='scale') value=transform.point(p,tm(affine.scale_xy(b,c.arguments[1])));
  if(c.operation==='rotate') value=transform.point(p,tm(affine.about_point(affine.rotate(b*180/Math.PI),c.arguments[1]?.x??0,c.arguments[1]?.y??0)));
  if(c.operation==='transform') value=transform.point(p,tm(am(b)));
  if(c.operation==='distanceTo') {
   if(b.type==='point') return compared(ph.distance(p,point(b)),c.result[0]);
   if(b.type==='line') return scope('No direct point-to-infinite-line distance API.');
   return compare({...c,input:b,arguments:[c.input]});
  }
  if(c.operation==='on') {
   if(b.type==='point') return scope('Upstream tolerance-based point equality differs from structural equality.');
   if(b.type==='polygon') {
    const path=new g.Path(fromArray(b.faces.map(f=>unwrap(g.subpath(fromArray(f.flatMap(pieces)))))));
    return compared(!(unwrap(containment.path_containment(p,path,new g.EvenOdd())) instanceof g.Outside));
   }
   return compare({...c,operation:'contains',input:b,arguments:[c.input]});
  }
  if(value!==undefined) return compared(value);
  return scope('No direct point/line side or infinite-line projection object API.');
 }
 if(c.input.type==='box'&&c.operation==='merge') {
  const bb=b=>new g.BoundingBox(new g.Point(b.xmin,b.ymin),new g.Point(b.xmax,b.ymax));
  const box=bounds.bounding_box_union(bb(c.input),bb(b));
  return compared({xmin:box.min.x,ymin:box.min.y,xmax:box.max.x,ymax:box.max.y});
 }
 if(c.input.type==='box'&&c.operation==='contains') {
  const boxes=pieces(b).map(s=>unwrap(bounds.segment_bounding_box(s))),q=c.input;
  return compared(boxes.every(v=>v.min.x>=q.xmin&&v.min.y>=q.ymin&&v.max.x<=q.xmax&&v.max.y<=q.ymax));
 }
 if(c.input.type==='box'&&c.operation==='intersect') return scope('Box.intersect is a Boolean bounding-box overlap query, not boundary intersections.');

 const infinite=s=>['line','ray'].includes(s?.type);
 if(infinite(c.input)) {
  if(c.operation==='intersect'&&!infinite(b)) return compare({...c,input:b,arguments:[c.input]});
  return {status:'scope-difference',reason:'No corresponding public infinite-line/ray object operation; bounded-shape intersections are compared separately.'};
 }
 const a=pieces(c.input);
 if(c.input.type==='face'&&['signedArea','area','orientation'].includes(c.operation)) {
  const signed=-a.reduce((sum,s)=>sum+area.signed_segment(s),0);
  return compared(c.operation==='signedArea'?signed:c.operation==='area'?Math.abs(signed):Math.abs(signed)<tolerance?0:Math.sign(signed));
 }
 if(c.operation==='definiteIntegral') {
  // These two fixtures are closed circles: integral y dx = -signed area.
  const value=-a.reduce((sum,s)=>sum+area.signed_segment(s),0);
  const error=Math.abs(value-c.result);
  return {status:error<=tolerance?'match':'needs-investigation',value,error};
 }
 if(c.operation==='breakToFunctional') {
  const s=c.input;
  const arc=new ellipse.CenterArcData(new ellipse.EllipsePoint(s.center.x,s.center.y),new ellipse.EllipsePoint(s.radius,s.radius),0,s.startAngle*180/Math.PI,(s.ccw?1:-1)*s.sweep*180/Math.PI);
  const cuts=[...ellipse.arc_projection_extrema(arc,new ellipse.EllipsePoint(1,0)),...ellipse.arc_projection_extrema(arc,new ellipse.EllipsePoint(0,1))].filter(t=>t>0&&t<1).sort((a,b)=>a-b);
  const result=[...ellipse.arc_split_many_inside(arc,fromArray(cuts))[0]];
  const points=result.slice(0,-1).map(a=>ellipse.arc_point(a,1));
  const reference=c.result.slice(0,-1).map(a=>a.end);
  return {status:matchingPoints(points,reference)?'match':'needs-investigation',pieces:result.length,referencePieces:c.result.length,points,reference};
 }
 if(['middle','tangentInStart','tangentInEnd'].includes(c.operation)) {
  let value;
  if(c.operation==='middle') value=unwrap(measure.subpath_point_at_length(unwrap(g.subpath(fromArray(a))),a.reduce((n,s)=>n+unwrap(measure.segment_length(s)),0)/2));
  else {
   const end=c.operation==='tangentInEnd';
   const d=unwrap(g.segment_derivative(end?a.at(-1):a[0],end?1:0));
   const scale=(end?-1:1)/Math.hypot(d.x,d.y); // Flatten's end tangent points back into the curve.
   value={x:d.x*scale,y:d.y*scale};
  }
  const error=dist(value,c.result);
  return {status:error<=tolerance?'match':'needs-investigation',value,error};
 }
 if(['reverse','transform','translate','rotate'].includes(c.operation)) {
  let actual;
  if(c.operation==='reverse') actual=a.slice().reverse().map(g.segment_reverse);
  else {
   let matrix;
   if(c.operation==='transform') matrix=affine.matrix(b.a,b.b,b.c,b.d,b.tx,b.ty);
   if(c.operation==='translate') matrix=affine.translate(b.x,b.y);
   if(c.operation==='rotate') matrix=affine.about_point(affine.rotate(b*180/Math.PI),c.arguments[1]?.x??0,c.arguments[1]?.y??0);
   actual=a.map(s=>unwrap(transform.segment(s,transform.from_tuple(affine.to_tuple(matrix)))));
  }
  const expected=pieces(c.result);
  if(actual.length!==expected.length) return {status:'needs-investigation',reason:'Adapter partition differs'};
  const error=Math.max(...actual.flatMap((s,i)=>[0,.25,.5,.75,1].map(t=>dist(unwrap(g.segment_point(s,t)),unwrap(g.segment_point(expected[i],t))))));
  return {status:error<=tolerance?'match':'needs-investigation',error};
 }
 if(c.operation==='length'||c.operation==='perimeter') {
  const value=a.reduce((n,s)=>n+unwrap(measure.segment_length(s)),0);
  return {status:Math.abs(value-c.result)<=tolerance?'match':'needs-investigation',value,error:Math.abs(value-c.result)};
 }
 if(c.operation==='box') {
  const boxes=a.map(s=>unwrap(bounds.segment_bounding_box(s)));
  const value={xmin:Math.min(...boxes.map(b=>b.min.x)),ymin:Math.min(...boxes.map(b=>b.min.y)),xmax:Math.max(...boxes.map(b=>b.max.x)),ymax:Math.max(...boxes.map(b=>b.max.y))};
  const error=Math.max(...Object.keys(value).map(k=>Math.abs(value[k]-c.result[k])));
  return {status:error<=tolerance?'match':'needs-investigation',value,error};
 }
 if(c.operation==='pointAtLength') {
  const subpath=unwrap(g.subpath(fromArray(a)));
  const value=unwrap(measure.subpath_point_at_length(subpath,b));
  const error=dist(value,c.result);
  return {status:error<=tolerance?'match':'needs-investigation',value,error};
 }
 if(c.operation==='contains'&&b.type==='point') {
  let value;
  if(c.input.type==='circle') {
   const found=unwrap(containment.subpath_containment(point(b),unwrap(g.subpath(fromArray(a))),new g.Nonzero()));
   value=!(found instanceof g.Outside);
  } else value=Math.min(...a.map(s=>unwrap(distance.segment_distance(point(b),s))))<tolerance;
  return {status:value===c.result?'match':'needs-investigation',value};
 }
 if(c.operation==='intersect') {
  let points=[],errors=[];
  if(infinite(b)) {
   const n=b.normal,denom=Math.hypot(n.x,n.y),direction=new g.Point(n.y/denom,-n.x/denom);
   if(c.input.type==='segment') {
    const signed=p=>(p.x-b.point.x)*n.x+(p.y-b.point.y)*n.y;
    if(signed(c.input.start)===0&&signed(c.input.end)===0&&c.result.length>1)
     return {status:'continuous-overlap-contract-difference',reason:'Supporting-line crossings enumerate isolated roots, not a continuous collinear interval.'};
   }
   for(const s of a) for(const [t,u] of unwrap(containment.segment_ray_crossings(s,point(b.point),direction))) {
    if(b.type!=='ray'||u>=-tolerance) points.push(unwrap(g.segment_point(s,t)));
   }
  } else {
   for(const left of a) for(const right of pieces(b)) {
    const result=intersections.segment(left,right);
    if(result.isOk()) points.push(...[...result[0]].map(h=>h.point));
    else errors.push(result[0].constructor.name);
   }
  }
  points=unique(points);
  if(errors.length) return {status:sameSupport(c.input,b)&&errors.every(e=>e==='OverlappingSegments')?'continuous-overlap-contract-difference':'needs-investigation',points,errors};
  const reference=unique(c.result);
  return {status:matchingPoints(points,reference)?'match':'needs-investigation',points,reference};
 }
 if(c.operation==='distanceTo') {
  if(b.type==='line') return {status:'scope-difference',reason:'No direct public distance-to-infinite-line query; do not silently clip the line.'};
  let candidates;
  if(b.type==='point') candidates=a.map(s=>{const value=unwrap(distance.segment_projection(point(b),s));return {distance:value.distance,left:value.point,right:point(b)};});
  else if(process.env.FLATTEN_DISTANCE_ADAPTER!=='exhaustive-segment-pairs') {
   const path=segments=>new g.Path(fromArray(segments.map(s=>unwrap(g.subpath(fromArray([s]))))));
   const value=unwrap(distance.path_path_closest_pair(path(a),path(pieces(b))));
   candidates=[{distance:value.distance,left:value.left_point,right:value.right_point}];
  } else candidates=a.flatMap(left=>pieces(b).map(right=>{const value=unwrap(distance.segment_segment_closest_pair(left,right));return {distance:value.distance,left:value.left_point,right:value.right_point};}));
  const best=candidates.reduce((a,b)=>a.distance<=b.distance?a:b);
  const error=Math.abs(best.distance-c.result[0]);
  return {status:error<=tolerance?'match':'needs-investigation',value:best,referenceDistance:c.result[0],error};
 }
 return {status:'scope-difference',reason:'Operation not adapted in this batch'};
}
if(!isMainThread) {
 try { parentPort.postMessage(compare(workerData)); }
 catch(e){parentPort.postMessage(e.scope?{status:'scope-difference',reason:e.scope,details:e}:{status:'needs-investigation',error:e.geometryError??String(e),phase,stack:e.stack,details:errorDetails(e.details)});}
} else {
 const allCalls=fs.readFileSync(new URL(`${batch}-calls.jsonl`,import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
 const selection=process.env.FLATTEN_CALL?Number(process.env.FLATTEN_CALL):null;
 if(selection!==null && (!Number.isInteger(selection)||selection<1||selection>allCalls.length)) throw Error('Invalid FLATTEN_CALL');
 const recheck=process.env.FLATTEN_RECHECK_FAILURES==='1';
 const previous=recheck?JSON.parse(fs.readFileSync(new URL(`${batch}-results.json`,import.meta.url),'utf8')):null;
 const ids=recheck?previous.rows.filter(r=>r.comparison.status==='needs-investigation').map(r=>r.call):selection===null?allCalls.map((_,i)=>i+1):[selection];
 const calls=ids.map(i=>allCalls[i-1]);
 const timeout=Number(process.env.FLATTEN_TIMEOUT_MS??30000);
 if(!Number.isFinite(timeout)||timeout<=0) throw Error('Invalid timeout');
 const rows=recheck?previous.rows.filter(r=>!ids.includes(r.call)):[];let cursor=0;
 async function lane(){while(cursor<calls.length){const i=cursor++,c=calls[i];const result=await new Promise(resolve=>{
  const worker=new Worker(new URL(import.meta.url),{workerData:c});
  const timer=setTimeout(()=>{worker.terminate();resolve({status:'needs-investigation',timeout:true});},timeout);
  worker.once('message',v=>{clearTimeout(timer);resolve(v);});worker.once('error',e=>{clearTimeout(timer);resolve({status:'needs-investigation',crash:String(e)});});
 });rows.push({call:ids[i],...c,comparison:result});}}
 await Promise.all(Array.from({length:4},lane));rows.sort((a,b)=>a.call-b.call);
 const counts={};for(const row of rows)counts[row.comparison.status]=(counts[row.comparison.status]??0)+1;
 const report={distanceAdapter:process.env.FLATTEN_DISTANCE_ADAPTER!=='exhaustive-segment-pairs'?'public-path-query':'exhaustive-segment-pairs',timeoutMs:timeout,implementation:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),diagnosticTolerance:tolerance,counts,rows};
 fs.writeFileSync(new URL(selection===null?`${batch}-results.json`:`${batch}-call${selection}-${process.env.FLATTEN_DISTANCE_ADAPTER==='exhaustive-segment-pairs'?'exhaustive':'public'}-results.json`,import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(counts);
 for(const row of rows.filter(r=>r.comparison.status==='needs-investigation'))console.log(row.call,row.test,JSON.stringify(row.comparison));
}
