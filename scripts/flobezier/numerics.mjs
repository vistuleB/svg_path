import fs from 'node:fs';
import {Worker,isMainThread,parentPort} from 'node:worker_threads';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as b from '../../test_portable/build/dev/javascript/svg_path/svg_path/bezier.mjs';
import * as m from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as d from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as k from '../../test_portable/build/dev/javascript/svg_path/svg_path/curvature.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as affine from '../../test_portable/build/dev/javascript/svg_path/svg_path/affine.mjs';
const classes=[null,null,g.Line,g.QuadraticBezier,g.CubicBezier];
const beziers=[null,null,b.LinearBezierData,b.QuadraticBezierData,b.CubicBezierData];
const segment=ps=>new classes[ps.length](...ps.map(p=>new g.Point(...p)));
const curve=ps=>new beziers[ps.length](...ps.map(p=>new b.BezierPoint(...p)));
function unwrap(r){if(!r.isOk())throw Error(r[0].constructor.name);return r[0];}
const xy=p=>[p.x,p.y];
const near=(a,b,tol)=>typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=tol;
function compare(c){
 const {operation:op,args:a,result:ref}=c;
 const ps=op==='length'?a[1]:a[0];
 if(c.error)return {status:'upstream-rejected-input',error:c.error};
 if(['flipAbout','flipHorizontally','flipVertically','rotate90About','rotate90','rotateAbout','rotateNeg90About','rotateNeg90','rotate','scale','transform','translate'].includes(op)){
 let matrix;
 switch(op){
 case 'transform': {const [[aa,bb,cc],[dd,ee,ff]]=a[1];matrix=affine.matrix(aa,dd,bb,ee,cc,ff);break;}
 case 'translate':matrix=affine.translate(...a[1]);break;
 case 'scale':matrix=affine.scale(a[1]);break;
 case 'flipHorizontally':matrix=affine.scale_xy(-1,1);break;
 case 'flipVertically':matrix=affine.scale_xy(1,-1);break;
 case 'rotate':matrix=affine.rotate(a[1]*180/Math.PI);break;
 case 'rotateAbout':matrix=affine.about_point(affine.rotate(a[1]*180/Math.PI),...a[2]);break;
 case 'rotate90':matrix=affine.rotate(90);break;
 case 'rotateNeg90':matrix=affine.rotate(-90);break;
 case 'rotate90About':matrix=affine.about_point(affine.rotate(90),...a[1]);break;
 case 'rotateNeg90About':matrix=affine.about_point(affine.rotate(-90),...a[1]);break;
 case 'flipAbout':{const angle=Math.atan2(a[2][1]-a[1][1],a[2][0]-a[1][0])*180/Math.PI;
 matrix=affine.about_point(affine.chain(affine.chain(affine.rotate(-angle),affine.scale_xy(1,-1)),affine.rotate(angle)),...a[1]);break;}
 }
 const ours=ps.map(p=>affine.point(matrix,...p));
 const tol=1e-10*Math.max(1,...ref.flat().map(Math.abs));
 return {status:ours.flat().every((x,i)=>near(x,ref.flat()[i],tol))?'matches-at-diagnostic-tolerance':'needs-investigation',ours,expected:ref};
 }
 if(ps.length===1)return {status:'point-input-api-difference'};
 if(ps.length>4)return {status:'unsupported-degree-api-difference'};
 if(op==='getBoundingBoxTight')return {status:'rotated-box-policy-difference'};
 const scale=Math.max(1,...ps.flat().map(Math.abs));
 const tol=1e-8+128*Number.EPSILON*scale;
 let ours,expected=ref,match=false,notes;
 try{
 switch(op){
 case 'area':ours=area.signed_segment(segment(ps));match=near(ours,ref,tol*scale);break;
 case 'evaluate1stDerivative':case 'evaluate2ndDerivative':
   ours=xy(unwrap((op==='evaluate1stDerivative'?g.segment_derivative:g.segment_second_derivative)(segment(ps),a[1])));match=ours.every((x,i)=>near(x,ref[i],tol));break;
 case 'length':{
   ours=unwrap(m.segment_length(unwrap(g.segment_between(segment(ps),...a[0]))));
   // FloBezier signed reversed integration; our reversed segment length is positive.
   expected=Math.abs(ref);
   match=near(ours,expected,1e-7+128*Number.EPSILON*Math.max(scale,expected));
   break;
 }
 case 'getTAtLength':
   if(a[1]<0||ref>1)return {status:'extended-length-domain-difference'};
   ours=unwrap(m.segment_parameter_at_length(segment(ps),a[1]));
   match=near(ours,ref,1e-7);break;
 case 'getBoundingBox':case 'getBounds':{
   const box=b.bounding_box(curve(ps));ours=[xy(box.min),xy(box.max)];expected=op==='getBounds'?ref.box:ref;
   match=ours.flat().every((x,i)=>near(x,expected.flat()[i],tol));break;
 }
 case 'closestPointOnBezier':case 'closestPointOnBezierCertified':{
   if(op==='closestPointOnBezier'&&a[2]===false)return {status:'exclude-endpoints-policy-difference'};
   if(op==='closestPointOnBezierCertified'&&((a[2]??0)!==0||(a[3]??1)!==1))return {status:'restricted-nearest-interval-adapter-pending'};
   const p=unwrap(d.segment_projection(new g.Point(...a[1]),segment(ps)));
   ours={t:p.at,p:xy(p.point),distance:p.distance};
   // Tied minimizers may choose different parameters under our contract.
   const refs=Array.isArray(ref)?ref:[ref];
   expected=Math.min(...refs.map(r=>Math.hypot(r.p[0]-a[1][0],r.p[1]-a[1][1])));
   match=near(p.distance,expected,tol);break;
 }
 case 'bezierSelfIntersection':{
   if(a[1]===false)return {status:'partial-extension-self-intersection-difference'};
   const xs=[...unwrap(b.cubic_self_intersections(curve(ps)))];
   ours=xs.flatMap(x=>[x.s,x.t]);
   if(ref.length===2&&ref[0]===ref[1]&&ours.length===0)return {status:'cusp-is-not-two-visits-contract-difference',ours};
   match=ours.length===ref.length&&ours.every((x,i)=>near(x,ref[i],1e-7));break;
 }
 case 'getInflections':
   ours=[...k.segment_inflection_parameters(segment(ps))];
   expected=ref.filter(t=>t>=0&&t<=1);
   match=ours.length===expected.length&&ours.every((x,i)=>near(x,expected[i],1e-7));break;
 case 'fromTo':{
   const s=unwrap(g.segment_between(segment(ps),a[1],a[2]));
   const ts=[0,.125,.5,.875,1];
   ours=ts.map(t=>xy(unwrap(g.segment_point(s,t))));
   expected=ts.map(t=>xy(b.point(curve(ref),t)));
   match=ours.flat().every((x,i)=>near(x,expected.flat()[i],tol));break;
 }
 case 'evalDeCasteljau':
   ours=xy(b.point(curve(ps),a[1]));match=ours.every((x,i)=>near(x,ref[i],tol));break;
 case 'curvature':
   expected=typeof ref==='string'?ref:-ref; // Visual-left in y-down coordinates.
   try{ours=unwrap(k.segment_left_normal_curvature(segment(ps),a[1]));}
   catch(e){if(ref==='NaN')return {status:'degenerate-curvature-error-vs-NaN',error:e.message};throw e;}
   match=near(ours,expected,1e-8*Math.max(1,Math.abs(expected)));break;
 default:throw Error('Unknown operation '+op);
 }
 return {status:match?'matches-at-diagnostic-tolerance':'needs-investigation',ours,expected,notes};
 }catch(e){return {status:'needs-investigation',error:e.message};}
}
if(!isMainThread){parentPort.on('message',c=>parentPort.postMessage(compare(c)));}
else{
 const calls=fs.readFileSync(new URL('numeric-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
 const rows=[];let cursor=0;
 async function lane(){
  let worker;
  while(cursor<calls.length){
   const index=cursor++,c=calls[index];
   if(!worker)worker=new Worker(new URL(import.meta.url));
   const result=await new Promise(resolve=>{
    const current=worker;
    const done=r=>{clearTimeout(timer);current.removeAllListeners('message');current.removeAllListeners('error');resolve(r);};
    const timer=setTimeout(()=>{current.terminate();worker=undefined;done({status:'needs-investigation',timeout:true});},5000);
    current.once('message',done);current.once('error',e=>{current.terminate();worker=undefined;done({status:'needs-investigation',crash:String(e)});});
    current.postMessage(c);
   });
   rows.push({call:index+1,...c,...result});
  }
  if(worker)await worker.terminate();
 }
 await Promise.all(Array.from({length:4},lane));rows.sort((a,b)=>a.call-b.call);
 const counts={};for(const r of rows)counts[r.status]=(counts[r.status]??0)+1;
 fs.writeFileSync(new URL('numeric-results.json',import.meta.url),JSON.stringify({counts,rows},null,2)+'\n');console.log(counts);
}
