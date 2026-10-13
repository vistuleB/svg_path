// Diagnostic only: exports private functions from a temporary compiled copy.
// Build first: (cd test_paperjs && gleam build --target javascript)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const repo=path.resolve(import.meta.dirname,'../..');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'svg-crossing-roots-'));
fs.cpSync(path.join(repo,'test_paperjs/build/dev/javascript'),scratch,{recursive:true});
const mod=path.join(scratch,'svg_path/svg_path.mjs');
fs.appendFileSync(mod,'\nexport {segment_line_crossings_with, segment_line_classified_roots, line_crossing_cubic_coefficients};\n');
const s=await import(pathToFileURL(mod));
const r=await import(pathToFileURL(path.join(scratch,'svg_path/svg_path/internal/root.mjs')));
const clean=v=>v&&typeof v==='object'?(v[Symbol.iterator]?[...v].map(clean):{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}):v;
function evaluate(v,t){v=v.slice();while(v.length>1)v=v.slice(1).map((b,i)=>v[i]*(1-t)+b*t);return v[0];}
// Experimental scalar Bernstein isolation: exact endpoint/sign tests and
// derivative partitions. This is an investigation, not a certified general solver.
function bernsteinRoots(v){
 const n=v.length-1;
 if(v.every(x=>x===0))return [];
 if(n===0)return [];
 const critical=bernsteinRoots(v.slice(1).map((b,i)=>n*(b-v[i]))).filter(t=>t>0&&t<1);
 const boundaries=[0,...critical,1], roots=[];
 for(const t of boundaries)if(evaluate(v,t)===0)roots.push(t);
 for(let i=1;i<boundaries.length;i++){
  let a=boundaries[i-1],b=boundaries[i],fa=evaluate(v,a),fb=evaluate(v,b);
  if(!(fa<0&&fb>0||fa>0&&fb<0))continue;
  for(let j=0;j<100;j++){
   const m=a+(b-a)/2,fm=evaluate(v,m);
   if(m===a||m===b)break;
   if(fm===0){a=b=m;break;}
   if(fa<0&&fm<0||fa>0&&fm>0){a=m;fa=fm;}else{b=m;fb=fm;}
  }
  roots.push(Math.abs(evaluate(v,a))<Math.abs(evaluate(v,b))?a:b);
 }
 return [...new Set(roots)].sort((a,b)=>a-b);
}
const options=(iterations=100,tol=1e-12)=>new s.CrossingOptions(100,tol,iterations);
function inspect(segment,point,normal){
 const pts=[segment.start,segment.control1,segment.control2,segment.end];
 const values=pts.map(p=>(p.x-point.x)*normal.x+(p.y-point.y)*normal.y);
 const coefficients=s.line_crossing_cubic_coefficients(...pts,point,normal);
 const projectedRoots=bernsteinRoots(values);
 const residual=t=>{const p=s.segment_point(segment,t)[0];return (p.x-point.x)*normal.x+(p.y-point.y)*normal.y;};
 return {values,coefficients,relativeZeroThreshold:Math.max(...coefficients.map(Math.abs))*1e-12,
  critical:clean(r.quadratic(3*coefficients[0],2*coefficients[1],coefficients[2])),
  candidates:clean(s.segment_line_classified_roots(segment,point,normal,1e-12,100)),
  baseline:clean(s.segment_line_crossings_with(segment,point,normal,options())),
  moreIterations:clean(s.segment_line_crossings_with(segment,point,normal,options(1000))),
  roots:projectedRoots.map(t=>({t,bernsteinResidual:evaluate(values,t),geometricResidual:residual(t)}))};
}
const witnesses=JSON.parse(fs.readFileSync(path.join(repo,'scripts/paperjs/boolean-crossing-witnesses.json')));
const results=[];
for(const w of witnesses){
 const ps=['start','control1','control2','end'].map(k=>w.context.segment[k]);
 let recovered;
 for(const axis of ['x','y'])for(const sign of [-1,1]){
  const origin=ps[3][axis]-w.context.controlValues[3]/sign;
  const values=ps.map(p=>sign*(p[axis]-origin));
  if(values.every((v,i)=>v===w.context.controlValues[i]))recovered={axis,sign,origin};
 }
 assert(recovered,`recover coordinate line ${w.id}`);
 const {axis,sign,origin}=recovered;
 const point=new s.Point(axis==='x'?origin:0,axis==='y'?origin:0);
 const normal=new s.Point(axis==='x'?sign:0,axis==='y'?sign:0);
 const segment=new s.CubicBezier(...ps.map(p=>new s.Point(p.x,p.y)));
 const row={id:w.id,line:recovered,...inspect(segment,point,normal)};
 assert.equal(row.baseline.type,'Error');
 assert(row.roots.every(x=>Math.abs(x.geometricResidual)<=1e-12));
 assert.equal(row.roots.length,w.id===107?2:1);
 assert(Math.abs(row.roots[0].t-w.floatRoot)<1e-15);
 results.push(row);
 console.log(w.id,'candidates',JSON.stringify(row.candidates),'roots',row.roots.map(x=>x.t));
}
const reductions=[];
for(const values of [[1,1,-1e-11,-1e-11],[-1000,-1000,1e-4,0]]){
 for(const reversed of [false,true]){
  const v=reversed?values.toReversed():values;
  const segment=new s.CubicBezier(...v.map((y,i)=>new s.Point(i/3,y)));
  reductions.push({reversed,...inspect(segment,new s.Point(0,0),new s.Point(0,1))});
 }
}
const sourceSha256=Object.fromEntries(['src/svg_path.gleam','src/svg_path/internal/root.gleam','src/svg_path/csg.gleam'].map(file=>[file,createHash('sha256').update(fs.readFileSync(path.join(repo,file))).digest('hex')]));
const report={sourceSha256,scope:'All eight captured crossing witnesses; experimental scalar isolation only, no production changes.',results,reductions};
fs.writeFileSync(path.join(repo,'scripts/paperjs/crossing-root-investigation.json'),JSON.stringify(report,null,2)+'\n');
console.log('scratch',scratch);
console.log('reductions',reductions.map(x=>({values:x.values,result:x.baseline,roots:x.roots})));

// A short decimal-control reduction retaining the original coordinate arithmetic.
const translatedReductions=[];
for(const coords of [[7.6,2,0,0],[8,1.9,0,0],[30,15,0,0],[7.6,1.9,0,0]]){
 const segment=new s.CubicBezier(...coords.map((y,i)=>new s.Point(i/3,y)));
 const row=inspect(segment,new s.Point(0,5e-12),new s.Point(0,1));
 translatedReductions.push({coords,...row});
}
report.translatedReductions=translatedReductions;
fs.writeFileSync(path.join(repo,'scripts/paperjs/crossing-root-investigation.json'),JSON.stringify(report,null,2)+'\n');
console.log('translated reductions',translatedReductions.map(x=>({coords:x.coords,result:x.baseline})));

// Optional experiment: retry failed cubic-line queries using scalar Bernstein
// isolation, in the temporary compiled copy only. Keep successful queries intact.
if(process.argv.includes('--screen')){
 let code=fs.readFileSync(mod,'utf8');
 const anchor='function segment_line_crossings_with(segment, point, normal, options) {';
 assert.equal(code.split(anchor).length,2);
 code=code.replace(anchor,anchor.replace('segment_line_crossings_with','baseline_segment_line_crossings_with'));
 code+='\n'+evaluate.toString()+'\n'+bernsteinRoots.toString()+`
function segment_line_crossings_with(segment, point, normal, options) {
 const baseline=baseline_segment_line_crossings_with(segment,point,normal,options);
 if(!(baseline instanceof Error) || !(baseline[0] instanceof CrossingMaxIterationsReached) || !(segment instanceof CubicBezier)) return baseline;
 const f=p=>(p.x-point.x)*normal.x+(p.y-point.y)*normal.y;
 const values=[segment.start,segment.control1,segment.control2,segment.end].map(f);
 const parameters=bernsteinRoots(values);
 const tolerance=options.signed_line_distance_tolerance*Math.hypot(normal.x,normal.y);
 const residuals=parameters.map(t=>f(segment_point(segment,t)[0]));
 const separated=values.every(v=>v>tolerance)||values.every(v=>v< -tolerance);
 const accepted=separated || parameters.length>0 && residuals.every(v=>Math.abs(v)<=tolerance);
 globalThis.crossingAudit??=[];
 globalThis.crossingAudit.push({values,parameters,residuals,tolerance,accepted,segment,point,normal,error:{estimate:baseline[0].estimate,value:baseline[0].value}});
 globalThis.crossingAuditReporter?.();
 if(!accepted) return baseline;
 return new Ok(toList(parameters));
}
`;
 // Use the runtime's exported list constructor without altering build output.

 fs.writeFileSync(mod,code);
 let probe=fs.readFileSync(path.join(repo,'scripts/paperjs/probe-booleans.mjs'),'utf8');
 probe=probe.replace("new URL('./booleans.json',import.meta.url)",JSON.stringify(path.join(repo,'scripts/paperjs/booleans.json')));
 probe=probe.replaceAll('../../test_portable/build/dev/javascript/svg_path/',pathToFileURL(path.join(scratch,'svg_path/')).href);
 // Only compare the eight failing cases in this diagnostic experiment.
 probe=probe.replace('const selected=process.argv[3]===undefined?fixtures:', 'const selected=process.argv[3]===undefined?fixtures.filter(f=>[103,107,128,129,130,131,168,169].includes(f.id)):');
 probe=probe.replace("let stage='startup';", "let stage='startup',rootAudit=[];");
 probe=probe.replace("status:'timeout',limitMs,stage", "status:'timeout',limitMs,stage,rootAudit");
 probe=probe.replace("stage=r.progress;return;", "stage=r.progress;if(r.rootAudit)rootAudit=r.rootAudit;return;");
 probe=probe.replace(" const f=workerData.fixture;", " const f=workerData.fixture;globalThis.crossingAuditReporter=()=>parentPort.postMessage({progress:'root-experiment',rootAudit:globalThis.crossingAudit});");
 probe=probe.replace("parentPort.postMessage(result);", "parentPort.postMessage({...result,rootAudit:globalThis.crossingAudit??[]});");
 fs.writeFileSync(path.join(scratch,'probe.mjs'),probe);
 console.log('Run experimental screen: PAPER_AUDIT_REPORT='+pathToFileURL(path.join(repo,'scripts/paperjs/crossing-root-experiment-screen.json')).href+' node '+path.join(scratch,'probe.mjs')+' /tmp/svg-path-paper-audit/node_modules/paper');
 const run=spawnSync(process.execPath,['--cpu-prof','--cpu-prof-dir='+scratch,path.join(scratch,'probe.mjs'),'/tmp/svg-path-paper-audit/node_modules/paper'],{stdio:'inherit',env:{...process.env,PAPER_AUDIT_REPORT:pathToFileURL(path.join(repo,'scripts/paperjs/crossing-root-experiment-screen.json')).href,PAPER_AUDIT_TIMEOUT_MS:'30000'}});
 assert.equal(run.status,0);
 const screened=JSON.parse(fs.readFileSync(path.join(repo,'scripts/paperjs/crossing-root-experiment-screen.json')));
 assert(screened.results.every(x=>!['harness-error','geometry-mismatch'].includes(x.status)));
 const later=screened.results.find(x=>x.id===128).rootAudit[1];
 const points=['start','control1','control2','end'].map(k=>later.segment[k]);
 report.subsequent128=inspect(new s.CubicBezier(...points.map(p=>new s.Point(p.x,p.y))),new s.Point(later.point.x,later.point.y),new s.Point(later.normal.x,later.normal.y));
 fs.writeFileSync(path.join(repo,'scripts/paperjs/crossing-root-investigation.json'),JSON.stringify(report,null,2)+'\n');
 const profiles=[];
 for(const file of fs.readdirSync(scratch).filter(x=>x.endsWith('.cpuprofile'))){
  const profile=JSON.parse(fs.readFileSync(path.join(scratch,file)));
  const seconds=(profile.endTime-profile.startTime)/1e6;
  if(seconds<20)continue;
  const nodes=new Map(profile.nodes.map(n=>[n.id,n]));
  const counts=new Map();
  for(const id of profile.samples??[]){
   const frame=nodes.get(id).callFrame;
   const key=frame.url.replace(/^file:.*svg-crossing-roots-[^/]+\//,'')+':'+frame.functionName;
   counts.set(key,(counts.get(key)??0)+1);
  }
  const top=[...counts].sort((a,b)=>b[1]-a[1]).slice(0,12).map(([functionName,samples])=>({functionName,samples}));
  profiles.push({seconds,totalSamples:profile.samples.length,top});
 }
 fs.writeFileSync(path.join(repo,'scripts/paperjs/crossing-root-profile.json'),JSON.stringify({scope:'30-second experimental screen; the busy long-lived worker is fixture 107, main thread is idle. Sample counts are diagnostic, not benchmarks.',profiles},null,2)+'\n');
}
