// Independent circular-arc scanlines: no native containment/distance queries.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import {path} from './triage-geometry.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const tau=2*Math.PI,mod=x=>(x%tau+tau)%tau;
function arc(p,q,c,r,sweep){return {p,q,c,r,start:Math.atan2(p.y-c.y,p.x-c.x),sweep};}
function source(input){return input.vertices.map((v,i)=>{const w=input.vertices[(i+1)%input.vertices.length],p={x:v[0],y:v[1]},q={x:w[0],y:w[1]},b=v[2];if(!b)return {p,q};const dx=q.x-p.x,dy=q.y-p.y,k=(1-b*b)/(4*b),c={x:(p.x+q.x)/2-dy*k,y:(p.y+q.y)/2+dx*k};return arc(p,q,c,Math.hypot(dx,dy)*(1+b*b)/(4*Math.abs(b)),4*Math.atan(b));});}
function output(path){return [...path.subpaths].flatMap(s=>[...s.segments].map(s=>{const p=s.start,q=s.end;if(s instanceof g.Line)return {p,q};if(!(s instanceof g.Arc)||s.radius.x!==s.radius.y)throw Error('Non-circular output');const dx=q.x-p.x,dy=q.y-p.y,d=Math.hypot(dx,dy),r=Math.max(Math.abs(s.radius.x),d/2),h=Math.sqrt(Math.max(0,(r-d/2)*(r+d/2))),sign=s.large_arc===s.sweep?-1:1,c={x:(p.x+q.x)/2-sign*dy*h/d,y:(p.y+q.y)/2+sign*dx*h/d};const start=Math.atan2(p.y-c.y,p.x-c.x),end=Math.atan2(q.y-c.y,q.x-c.x);return arc(p,q,c,r,s.sweep?mod(end-start):-mod(start-end));}));}
function onArc(s,p){if(!s.c)return true;const angle=Math.atan2(p.y-s.c.y,p.x-s.c.x),delta=s.sweep>0?mod(angle-s.start):mod(s.start-angle);return delta<=Math.abs(s.sweep)+1e-12;}
function cross(s,y){if(!s.c){if((s.p.y>y)===(s.q.y>y))return [];return [{x:s.p.x+(y-s.p.y)*(s.q.x-s.p.x)/(s.q.y-s.p.y),w:Math.sign(s.q.y-s.p.y)}];}const dy=y-s.c.y,disc=(s.r-dy)*(s.r+dy);if(disc<=0)return [];const h=Math.sqrt(disc);return [-h,h].map(dx=>({x:s.c.x+dx,y,w:Math.sign(s.sweep)*Math.sign(dx)})).filter(p=>onArc(s,p));}
function intersections(a,b){
 if(!a.c&&!b.c){const ux=a.q.x-a.p.x,uy=a.q.y-a.p.y,vx=b.q.x-b.p.x,vy=b.q.y-b.p.y,den=ux*vy-uy*vx;if(den===0)return [];const dx=b.p.x-a.p.x,dy=b.p.y-a.p.y,t=(dx*vy-dy*vx)/den,u=(dx*uy-dy*ux)/den;return t>=0&&t<=1&&u>=0&&u<=1?[{x:a.p.x+t*ux,y:a.p.y+t*uy}]:[];}
 if(!a.c)return intersections(b,a);
 if(!b.c){const dx=b.q.x-b.p.x,dy=b.q.y-b.p.y,ox=b.p.x-a.c.x,oy=b.p.y-a.c.y,A=dx*dx+dy*dy,B=2*(ox*dx+oy*dy),C=ox*ox+oy*oy-a.r*a.r,D=B*B-4*A*C;if(D<0)return [];return [-1,1].map(sign=>(-B+sign*Math.sqrt(D))/(2*A)).filter(t=>t>=0&&t<=1).map(t=>({x:b.p.x+t*dx,y:b.p.y+t*dy})).filter(p=>onArc(a,p));}
 const dx=b.c.x-a.c.x,dy=b.c.y-a.c.y,d=Math.hypot(dx,dy);if(d===0||d>a.r+b.r||d<Math.abs(a.r-b.r))return [];const x=(a.r*a.r-b.r*b.r+d*d)/(2*d),h=Math.sqrt(Math.max(0,(a.r-x)*(a.r+x)));return [-1,1].map(sign=>({x:a.c.x+x*dx/d-sign*h*dy/d,y:a.c.y+x*dy/d+sign*h*dx/d})).filter(p=>onArc(a,p)&&onArc(b,p));
}
function intervals(events,operation){events.sort((a,b)=>a.x-b.x);let w=[0,0,0],start=null,out=[];for(let i=0;i<events.length;){const x=events[i].x;do{w[events[i].group]+=events[i].w;i++;}while(i<events.length&&events[i].x===x);const inside=operation(w);if(inside&&start===null)start=x;if(!inside&&start!==null){out.push([start,x]);start=null;}}if(start!==null)throw Error('Unbalanced scanline');return out;}
function boundaryDistance(ss,p){return Math.min(...ss.map(s=>{if(!s.c){const dx=s.q.x-s.p.x,dy=s.q.y-s.p.y,t=Math.max(0,Math.min(1,((p.x-s.p.x)*dx+(p.y-s.p.y)*dy)/(dx*dx+dy*dy)));return Math.hypot(p.x-s.p.x-t*dx,p.y-s.p.y-t*dy);}const d=Math.hypot(p.x-s.c.x,p.y-s.c.y);return onArc(s,p)?Math.abs(d-s.r):Math.min(Math.hypot(p.x-s.p.x,p.y-s.p.y),Math.hypot(p.x-s.q.x,p.y-s.q.y));}));}
function symmetricWidth(a,b){const e=[];for(const [l,r]of a)e.push({x:l,group:0,w:1},{x:r,group:0,w:-1});for(const [l,r]of b)e.push({x:l,group:1,w:1},{x:r,group:1,w:-1});return intervals(e,w=>(w[0]!==0)!==(w[1]!==0));}
function splitCycles(ss){if(!ss.length)return [];const key=p=>`${p.x},${p.y}`;let vertices=[key(ss[0].p)],pending=[],cycles=[];for(const segment of ss){if(pending.length===0)vertices=[key(segment.p)];pending.push(segment);const end=key(segment.q),index=vertices.indexOf(end);if(index<0)vertices.push(end);else{cycles.push(pending.slice(index));pending=pending.slice(0,index);vertices=vertices.slice(0,index+1);}}if(pending.length)throw Error('Open cycle');return cycles;}
function properties(ss){let area=0,length=0,points=[];for(const s of ss){points.push(s.p,s.q);if(!s.c){area+=(s.p.x*s.q.y-s.q.x*s.p.y)/2;length+=Math.hypot(s.q.x-s.p.x,s.q.y-s.p.y);}else{area+=(s.c.x*(s.q.y-s.p.y)-s.c.y*(s.q.x-s.p.x)+s.r*s.r*s.sweep)/2;length+=s.r*Math.abs(s.sweep);for(const t of [0,Math.PI/2,Math.PI,3*Math.PI/2]){const p={x:s.c.x+s.r*Math.cos(t),y:s.c.y+s.r*Math.sin(t)};if(onArc(s,p))points.push(p);}}}return {area,length,bounds:[Math.min(...points.map(p=>p.x)),Math.min(...points.map(p=>p.y)),Math.max(...points.map(p=>p.x)),Math.max(...points.map(p=>p.y))]};}
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const wanted=process.env.CASE_TEST??'test_specific::debug_assert_stitching_slices_reported';
for(const c of cases.filter(c=>c.kind==='boolean'&&(process.env.CASE_ID?c.id===process.env.CASE_ID:c.test===wanted&&c.operation==='Xor'))){
 const options=new csg.Options(Number(process.env.TOLERANCE??1e-6),Number(process.env.MIN_LENGTH??1e-5));
 const cached=process.env.RAW_INPUT?JSON.parse(fs.readFileSync(process.env.RAW_INPUT)):null;
 const operation={Or:csg.union_path_with,And:csg.intersection_path_with,Not:csg.difference_path_with,Xor:csg.symmetric_difference_path_with}[c.operation];
 let result=cached?{isOk:()=>true,0:{subpaths:[]}}:operation(path(c.input),path(c.other),new g.Nonzero(),options);if(!result.isOk())throw result[0];
 let preSnap=null;
 if(process.env.PRE_SNAP && !cached){
  const fn={Or:csg.union_with,And:csg.intersection_with,Not:csg.difference_with,Xor:csg.symmetric_difference_with}[c.operation];
  const detailed=fn(path(c.input),path(c.other),new g.Nonzero(),options);if(!detailed.isOk())throw detailed[0];
  const edges=[...detailed[0].build.graph.edges],shape=s=>JSON.stringify(Object.fromEntries(Object.entries(s).filter(([k])=>!['start','end'].includes(k)))),dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
  const subs=[];preSnap={connectors:0,maxEndpointAdjustment:0};
  for(const sub of detailed[0].path.subpaths){
   const selected=[...sub.segments].map(out=>{
    const candidates=edges.flatMap(e=>[e.segment,g.segment_reverse(e.segment)]).filter(s=>s.constructor===out.constructor&&shape(s)===shape(out)).map(s=>({s,gap:Math.max(dist(s.start,out.start),dist(s.end,out.end))})).sort((a,b)=>a.gap-b.gap);
    if(!candidates.length||candidates[0].gap>options.tolerance)throw Error('No conforming stored edge');
    preSnap.maxEndpointAdjustment=Math.max(preSnap.maxEndpointAdjustment,candidates[0].gap);return candidates[0].s;
   });
   const joined=[];for(let i=0;i<selected.length;i++){const a=selected[i],b=selected[(i+1)%selected.length];joined.push(a);if(a.end.x!==b.start.x||a.end.y!==b.start.y){joined.push(new g.Line(a.end,b.start));preSnap.connectors++;}}
   const built=g.subpath(toList(joined));if(!built.isOk())throw built[0];subs.push(built[0]);
  }
  result={isOk:()=>true,0:new g.Path(toList(subs))};
 }

 const groups=cached?cached.groups:[source(c.input),source(c.other),output(result[0])],all=(process.env.INPUT_MODEL==='svg'?(groups[0]=output(path(c.input)),groups[1]=output(path(c.other)),groups.flat()):groups.flat());if(process.env.SCAN_AXIS==='x')for(const s of all){const rotate=p=>({x:-p.y,y:p.x});s.p=rotate(s.p);s.q=rotate(s.q);if(s.c){s.c=rotate(s.c);s.start=Math.atan2(s.p.y-s.c.y,s.p.x-s.c.x);}}const ys=all.flatMap(s=>[s.p.y,s.q.y,...(s.c?[s.c.y-s.r,s.c.y+s.r]:[])]);
 for(let i=0;i<all.length;i++)for(let j=0;j<i;j++)for(const p of intersections(all[i],all[j]))ys.push(p.y);
 if(process.env.RAW_OUTPUT)fs.writeFileSync(process.env.RAW_OUTPUT,JSON.stringify({groups,options,id:c.id}));
 const levels=[...new Set(ys)].sort((a,b)=>a-b);let skippedNarrowStrips=0,checked=0,maxWidth=0,maxEndpointDelta=0,topology=0,maxWitnessClearance=0,witnesses=[];
 for(let i=1;i<levels.length;i++)for(const t of [.25,.5,.75]){if(levels[i]-levels[i-1]<1e-11){skippedNarrowStrips++;continue;}const y=levels[i-1]+t*(levels[i]-levels[i-1]);if(y===levels[i-1]||y===levels[i])continue;const events=groups.flatMap((ss,group)=>ss.flatMap(s=>cross(s,y).map(v=>({...v,group}))));const expected=intervals(events.filter(e=>e.group<2),w=>({Or:w[0]!==0||w[1]!==0,And:w[0]!==0&&w[1]!==0,Not:w[0]!==0&&w[1]===0,Xor:(w[0]!==0)!==(w[1]!==0)})[c.operation]),actual=intervals(events.filter(e=>e.group===2),w=>w[2]!==0),diff=symmetricWidth(expected,actual),width=diff.reduce((s,[a,b])=>s+b-a,0);for(const [l,r] of diff){const p={x:(l+r)/2,y};maxWitnessClearance=Math.max(maxWitnessClearance,boundaryDistance(all,p));}checked++;maxWidth=Math.max(maxWidth,width);if(expected.length!==actual.length)topology++;else for(let k=0;k<expected.length;k++)for(let j=0;j<2;j++)maxEndpointDelta=Math.max(maxEndpointDelta,Math.abs(expected[k][j]-actual[k][j]));if(width>1e-5&&witnesses.length<12)witnesses.push({y,width,expected,actual,clearances:diff.map(([l,r])=>groups.map(ss=>boundaryDistance(ss,{x:(l+r)/2,y})))});}
 console.log(JSON.stringify({id:c.id,test:c.test,operation:c.operation,preSnap,scanAxis:process.env.SCAN_AXIS??'y',inputModel:process.env.INPUT_MODEL??'bulge',decomposedCycles:splitCycles(groups[2]).map(properties),upstreamProperties:[...c.positive,...c.negative],options,maxWitnessClearance,contours:cached?null:[...result[0].subpaths].length,upstreamPositive:c.positive.length,upstreamNegative:c.negative.length,eventLevels:levels.length,skippedNarrowStrips,checked,maxSymmetricDifferenceWidth:maxWidth,maxMatchedEndpointDelta:maxEndpointDelta,topologyDifferenceScanlines:topology,witnesses,output:cached?null:[...result[0].subpaths].map(s=>[...s.segments])}));
}
