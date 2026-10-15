import fs from 'node:fs';
import {Worker,isMainThread,parentPort} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as b from '../../test_portable/build/dev/javascript/svg_path/svg_path/bezier.mjs';
import * as m from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as d from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as k from '../../test_portable/build/dev/javascript/svg_path/svg_path/curvature.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as affine from '../../test_portable/build/dev/javascript/svg_path/svg_path/affine.mjs';
import * as overlaps from '../../test_portable/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import {toList} from '../../test_portable/build/dev/javascript/gleam_stdlib/gleam.mjs';
const classes=[null,null,g.Line,g.QuadraticBezier,g.CubicBezier];
const beziers=[null,null,b.LinearBezierData,b.QuadraticBezierData,b.CubicBezierData];
const segment=ps=>new classes[ps.length](...ps.map(p=>new g.Point(...p)));
const curve=ps=>new beziers[ps.length](...ps.map(p=>new b.BezierPoint(...p)));
function unwrap(r){if(!r.isOk())throw Error(r[0].constructor.name);return r[0];}
const xy=p=>[p.x,p.y];
const near=(a,b,tol)=>typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=tol;
function evaluate(ps,t){let q=ps.map(p=>p.slice());while(q.length>1)q=q.slice(1).map((p,i)=>p.map((x,j)=>(1-t)*q[i][j]+t*x));return q[0];}
function compare(c){
 const {operation:op,args:a,result:ref}=c;
 if(c.error)return {status:'upstream-rejected-input',error:c.error};
 let ps=op==='circleBezierIntersection'?a[1]:op==='isBezierPieceZeroLength'?a[0].ps:a[0];
 if(op==='getDistanceToLineFunction')return {status:'infinite-signed-line-vs-clamped-segment-contract'};
 if(ps.length===1)return {status:'point-input-api-difference'};
 const scale=Math.max(1,...ps.flat().map(Math.abs)),tol=1e-8+128*Number.EPSILON*scale;
 let ours,expected=ref,match=false;
 try{
 switch(op){
 case 'getEndpointIntersections':{
 const pieces=[...unwrap(overlaps.segment(segment(ps),segment(a[1])))];
 if(ref.length<2){ours=pieces;expected=[];match=pieces.length===0;break;}
 ours=pieces.map(x=>[[x.left_from,x.right_from],[x.left_to,x.right_to]]).flat();expected=ref.map(x=>[x.t1,x.t2]);
 match=ours.length===expected.length&&expected.every(p=>ours.some(q=>near(p[0],q[0],1e-7)&&near(p[1],q[1],1e-7)));break;
 }

 case 'isBezierPieceZeroLength':ours=unwrap(m.segment_is_zero_length(unwrap(g.segment_between(segment(ps),...a[0].ts)),0));match=ours===ref;break;
 case 'controlPointLinesLength':ours=unwrap(m.segment_length_upper_bound(segment(ps)));match=near(ours,ref,tol);break;
 case 'getControlPointBox':{
 const box=unwrap(bounds.points_bounding_box(toList(ps.map(p=>new g.Point(...p)))));ours=[xy(box.min),xy(box.max)];match=ours.flat().every((x,i)=>near(x,ref.flat()[i],tol));break;
 }
 case 'getXBoundsTight':case 'getYBoundsTight':{
 const i=op==='getXBoundsTight'?0:1,axis=i?'Y':'X';const box=b.bounding_box(curve(ps));ours=[xy(box.min)[i],xy(box.max)[i]];
 expected=[ref['min'+axis].box,ref['max'+axis].box];match=ours.every((x,j)=>x>=expected[j][0][i]-tol&&x<=expected[j][1][i]+tol);break;
 }
 case 'reverse':case 'toCubic':case 'lineToCubic':case 'quadraticToCubic':{
 const s=op==='reverse'?g.segment_reverse(segment(ps)):[...g.segment_to_cubic_beziers(segment(ps))][0];
 const ts=[0,.125,.5,.875,1];ours=ts.map(t=>xy(unwrap(g.segment_point(s,t))));expected=ts.map(t=>evaluate(ref,t));match=ours.flat().every((x,i)=>near(x,expected.flat()[i],tol));break;
 }
 case 'getHodograph':{
 const ts=[0,.125,.5,.875,1];ours=ts.map(t=>xy(unwrap(g.segment_derivative(segment(ps),t))));expected=ts.map(t=>evaluate(ref,t));match=ours.flat().every((x,i)=>near(x,expected.flat()[i],tol));break;
 }
 case 'closestPointsBetweenBeziers':{
 if(a[2]===0)return {status:'zero-tolerance-contract-difference'};
 ours=unwrap(d.segment_segment_closest_pair(segment(ps),segment(a[1])));expected=Math.min(...ref.map(x=>x.d));match=near(ours.distance,expected,tol);break;
 }
 case 'circleBezierIntersection':{
 const {center:[cx,cy],radius:r}=a[0];const p=new g.Point(cx+r,cy),q=new g.Point(cx-r,cy),radius=new g.Point(r,r);
 const arcs=[new g.Arc(p,radius,0,false,true,q),new g.Arc(q,radius,0,false,true,p)];
 const hits=arcs.flatMap(arc=>[...unwrap(ix.segment(segment(ps),arc))]);
 ours=hits.map(x=>x.left_t).sort((x,y)=>x-y).filter((x,i,all)=>i===0||x-all[i-1]>1e-7);
 if(ps.every(p=>p[0]===ps[0][0]&&p[1]===ps[0][1]))return {status:'constant-curve-parameter-convention',ours,expected:ref};
 expected=ref.map(x=>x.t).sort((x,y)=>x-y);match=ours.length===expected.length&&ours.every((x,i)=>near(x,expected[i],1e-7));break;
 }
 case 'splitByLength':{
 const pieces=[...unwrap(m.segment_subdivide_to_max_length(segment(ps),a[1]))];
 const lengths=pieces.map(s=>unwrap(m.segment_length(s)));
 ours={pieces:pieces.length,lengths};expected={maximumLength:a[1],upstreamPieces:ref.length-1};
 match=lengths.every(x=>x<=a[1]+1e-7)&&near(lengths.reduce((x,y)=>x+y,0),unwrap(m.segment_length(segment(ps))),1e-6);
 break;
 }
 case 'splitByDeviationFromStraightLine':case 'quadraticToPolyline':{
 const pieces=[...unwrap(g.segment_to_lines_with(segment(ps),new g.LinearizeOptions(a[1],32)))];
 let maxDeviation=0;for(let i=0;i<=1000;i++){const p=new g.Point(...evaluate(ps,i/1000));maxDeviation=Math.max(maxDeviation,Math.min(...pieces.map(s=>g.point_to_line_projection(p,s.start,s.end).distance)));}
 ours={pieces:pieces.length,sampledMaxDeviation:maxDeviation};expected={tolerance:a[1],upstreamPieces:ref.length-1};match=maxDeviation<=a[1]+tol;break;
 }
 default:throw Error('Unadapted operation '+op);
 }
 return {status:match?'matches-adapted-contract':'needs-investigation',ours,expected};
 }catch(e){return {status:op==='closestPointsBetweenBeziers'&&e instanceof RangeError&&e.message.includes('call stack')?'confirmed-closest-pair-stack-overflow':'needs-investigation',error:e.message,stack:e.stack};}
}
if(!isMainThread){parentPort.on('message',c=>parentPort.postMessage(compare(c)));}
else{
 const calls=fs.readFileSync(new URL('remaining-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
 const rows=[];let cursor=0;
 async function lane(){
  let worker;
  while(cursor<calls.length){
   const index=cursor++,c=calls[index];
   if(!worker)worker=new Worker(new URL(import.meta.url));
   const result=await new Promise(resolve=>{
    const current=worker;
    const done=r=>{clearTimeout(timer);current.removeAllListeners('message');current.removeAllListeners('error');resolve(r);};
    const timer=setTimeout(()=>{current.terminate();worker=undefined;done({status:'needs-investigation',timeout:true});},Number(process.env.FLO_TIMEOUT_MS ?? 5000));
    current.once('message',done);current.once('error',e=>{current.terminate();worker=undefined;done({status:'needs-investigation',crash:String(e)});});
    current.postMessage(c);
   });
   rows.push({call:index+1,...c,...result});
  }
  if(worker)await worker.terminate();
 }
 await Promise.all(Array.from({length:4},lane));rows.sort((a,b)=>a.call-b.call);
 const counts={};for(const r of rows)counts[r.status]=(counts[r.status]??0)+1;
 fs.writeFileSync(new URL('remaining-results.json',import.meta.url),JSON.stringify({counts,rows},null,2)+'\n');console.log(counts);
}
