// No production changes. Deterministic conditioning grid, not workload frequency.
import fs from 'node:fs';
import * as ellipse from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import * as trig from '../../test_portable/build/dev/javascript/svg_path/svg_path/trig.mjs';
import {solve} from './ellipse-double-double-kernel.mjs';
function native(a){const r=ellipse.endpoint_to_center(new ellipse.EndpointArcData(new ellipse.EllipsePoint(a.start.x,a.start.y),new ellipse.EllipsePoint(a.radius.x,a.radius.y),a.x_axis_rotation,false,true,new ellipse.EllipsePoint(a.end.x,a.end.y)));return r.isOk()?r[0]:null;}
function condition(a){
 const rx=Math.abs(a.radius.x),ry=Math.abs(a.radius.y),dx=(a.start.x-a.end.x)/2,dy=(a.start.y-a.end.y)/2,c=trig.cos_degrees(a.x_axis_rotation),s=trig.sin_degrees(a.x_axis_rotation);
 const u=(c*dx+s*dy)/rx,v=(-s*dx+c*dy)/ry,lambda=u*u+v*v;
 // Sensitivity to rounding in rotation, including cancellation with unequal axes.
 const k=Math.max(1,lambda+Math.abs(u)*(Math.abs(dx)+Math.abs(dy))/rx+Math.abs(v)*(Math.abs(dx)+Math.abs(dy))/ry);
 return {lambda,gap:Math.abs(1-lambda),k};
}
const rows=[];
function add(input,meta){const actual=native(input),candidate=solve(input),q=condition(input),size=Math.max(input.radius.x,input.radius.y);rows.push({...meta,input,...q,nativeErrorVsDD:actual?Math.hypot(actual.center.x-candidate.center.x,actual.center.y-candidate.center.y)/size:null,actual,candidate});}
for(const ratio of [.000001,.001,.5,2,1000,1000000])for(const scale of [1/1024,1,1024])for(const rotation of [0,17,37,73,137])for(const chordAngle of [13,53,89])for(const margin of [-.25,-1e-4,-1e-6,-1e-8,-1e-10,-1e-12,-1e-14,0,1e-14,1e-10,1e-6]){
 const theta=chordAngle*Math.PI/180,c=trig.cos_degrees(rotation),s=trig.sin_degrees(rotation),rx=1000*scale,ry=rx*ratio,radial=Math.sqrt(1+margin),x=rx*Math.cos(theta)*radial,y=ry*Math.sin(theta)*radial;
 const wx=c*x-s*y,wy=s*x+c*y;
 add({start:{x:wx,y:wy},end:{x:-wx,y:-wy},radius:{x:rx,y:ry},x_axis_rotation:rotation,large_arc:false,sweep:true},{family:'grid',ratio,scale,rotation,chordAngle,margin});
}
for(const r of JSON.parse(fs.readFileSync(new URL('./ellipse-rotation-inputs.json',import.meta.url))))add(r.input,{family:'audit'});
// Probe the proposed cutoff locally, using iterative adjustment because k varies
// with chord length. Very ill-conditioned axes can require fallback everywhere.
for(const ratio of [.01,.1,.5,2,10,100])for(const rotation of [17,37,73])for(const factor of [.5,.9,.99,1.01,1.1,2])for(const sign of [-1,1]) {
 const theta=53*Math.PI/180,c=trig.cos_degrees(rotation),s=trig.sin_degrees(rotation),rx=1000,ry=rx*ratio;
 let margin=0,input;
 for(let i=0;i<8;i++){
  const radial=Math.sqrt(Math.max(.01,1+margin)),x=rx*Math.cos(theta)*radial,y=ry*Math.sin(theta)*radial;
  input={start:{x:c*x-s*y,y:s*x+c*y},end:{x:-c*x+s*y,y:-s*x-c*y},radius:{x:rx,y:ry},x_axis_rotation:rotation,large_arc:false,sweep:true};
  const q=condition(input);margin=sign*Math.min(.8,1e-8*q.k*q.k*factor);
 }
 add(input,{family:'threshold-boundary',ratio,rotation,factor,sign});
}
// Ordinary well-conditioned controls: selected spans stay away from 180 degrees.
for(const ratio of [.1,.5,2,10])for(const rotation of [17,37,73])for(const span of [30,90,150,170,175,179]){
 const chord=Math.sin(span*Math.PI/360),theta=53*Math.PI/180,c=trig.cos_degrees(rotation),s=trig.sin_degrees(rotation),x=1000*Math.cos(theta)*chord,y=1000*ratio*Math.sin(theta)*chord;
 add({start:{x:c*x-s*y,y:s*x+c*y},end:{x:-c*x+s*y,y:-s*x-c*y},radius:{x:1000,y:1000*ratio},x_axis_rotation:rotation,large_arc:false,sweep:true},{family:'ordinary',ratio,rotation,span});
}
const summaries=[];
for(const threshold of [1e-12,1e-10,1e-8,1e-6])for(const power of [0,1,2]){
 const selected=rows.filter(r=>r.gap<=threshold*r.k**power),outside=rows.filter(r=>r.gap>threshold*r.k**power);
 const worst=outside.reduce((a,b)=>b.nativeErrorVsDD>(a?.nativeErrorVsDD??-1)?b:a,null);
 summaries.push({threshold,power,fallbacks:selected.length,total:rows.length,maxOutsideRelativeError:worst?.nativeErrorVsDD,worst:worst&&{ratio:worst.ratio,scale:worst.scale,rotation:worst.rotation,chordAngle:worst.chordAngle,margin:worst.margin,gap:worst.gap,k:worst.k},outsideAbove1e_12:outside.filter(r=>r.nativeErrorVsDD>1e-12).length});
}
console.log(JSON.stringify({summaries,rows},null,2));
