import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import * as current from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import * as precise from '../../test_portable/build/dev/javascript/svg_path/svg_path/internal/ellipse_precision.mjs';
const grid=JSON.parse(fs.readFileSync(new URL('./ellipse-threshold-grid.json',import.meta.url))).rows;
const oracle=JSON.parse(fs.readFileSync(new URL('./ellipse-threshold-oracle.json',import.meta.url))).rows;
function data(e,a){return new e.EndpointArcData(new e.EllipsePoint(a.start.x,a.start.y),new e.EllipsePoint(a.radius.x,a.radius.y),a.x_axis_rotation,a.large_arc,a.sweep,new e.EllipsePoint(a.end.x,a.end.y));}
const rows=grid.map((r,index)=>{
 const a=r.input,result=current.endpoint_to_center(data(current,a));if(!result.isOk())throw {index,result};
 const arc=result[0],size=Math.max(a.radius.x,a.radius.y);
 const endpointError=Math.max(...[0,1].map((t)=>{const p=current.arc_point(arc,t),q=t?a.end:a.start;return Math.hypot(p.x-q.x,p.y-q.y)/size;}));
 const fallback=precise.convert(a.start.x,a.start.y,a.end.x,a.end.y,a.radius.x,a.radius.y,a.x_axis_rotation,a.large_arc,a.sweep).isOk();
 return {index,center:arc.center,radius:arc.radius,endpointError,fallback,expectedFallback:r.gap<=1e-8*r.k*r.k};
});
const oracleChecks=oracle.map(r=>{const actual=rows[r.index],size=Math.max(...Object.values(grid[r.index].input.radius));return {index:r.index,relativeCenterError:Math.hypot(actual.center.x-Number(r.expected[0]),actual.center.y-Number(r.expected[1]))/size};});
let timings=null;
if(process.env.BASELINE_BUILD){
 const old=await import(`${process.env.BASELINE_BUILD}/svg_path/svg_path/ellipse.mjs`);
 timings={};
 for(const family of ['ordinary','audit']){
  const inputs=grid.filter(r=>r.family===family).map(r=>r.input);
  const oldData=inputs.map(a=>data(old,a)),newData=inputs.map(a=>data(current,a));let sink=0;
  for(let i=0;i<3000;i++){old.endpoint_to_center(oldData[i%inputs.length]);current.endpoint_to_center(newData[i%inputs.length]);}
  const samples=[];
  for(let repeat=0;repeat<7;repeat++){
   const n=10000,measure=(module,ds)=>{let start=performance.now();for(let i=0;i<n;i++)sink+=module.endpoint_to_center(ds[i%ds.length])[0].center.x;return (performance.now()-start)*1e6/n;};
   if(repeat%2===0){const before=measure(old,oldData),after=measure(current,newData);samples.push({before,after});}
   else {const after=measure(current,newData),before=measure(old,oldData);samples.push({before,after});}
  }
  timings[family]={unit:'nanoseconds per conversion',callsPerSample:10000,samples,sink};
 }
}
console.log(JSON.stringify({summary:{cases:rows.length,dispatchMismatches:rows.filter(r=>r.fallback!==r.expectedFallback).length,maxRelativeEndpointError:Math.max(...rows.map(r=>r.endpointError)),oracleCases:oracleChecks.length,maxRelativeCenterErrorVsRoundedOracle:Math.max(...oracleChecks.map(r=>r.relativeCenterError))},timings,oracleChecks,rows},null,2));

// Diagnostic acceptance targets from the threshold experiment, not API bounds.
if (rows.some(r => r.fallback !== r.expectedFallback || r.endpointError > 1e-12)
    || oracleChecks.some(r => r.relativeCenterError > 1e-12)) {
  process.exitCode = 1;
}
