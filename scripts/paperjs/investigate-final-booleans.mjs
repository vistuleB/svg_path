// Diagnostic instrumentation in a temporary compiled copy; production is unchanged.
// Build test_paperjs for JavaScript, then run with argument 122 or 107.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import inspector from 'node:inspector';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'../..');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'svg-final-booleans-'));
fs.cpSync(path.join(root,'test_paperjs/build/dev/javascript'),scratch,{recursive:true});
const trace=[];globalThis.auditTrace=trace;
function edit(file,fn){const p=path.join(scratch,'svg_path',file);fs.writeFileSync(p,fn(fs.readFileSync(p,'utf8')));}
function wrap(s,name,body){const anchor=`export function ${name}(`;if(s.split(anchor).length!==2)throw Error('Missing '+name);return s.replace(anchor,`function audit_original_${name}(`)+`\nexport function ${name}(...args) { ${body} }\n`;}
edit('svg_path/arrangement.mjs',s=>{
 s=s.replaceAll('return new Error(InternalError$InternalNormalizationError$const);','globalThis.auditTrace.push({kind:"normalization-site",stack:new globalThis.Error().stack}); return new Error(InternalError$InternalNormalizationError$const);');
 s=s.replace('function unique_vertex_for_endpoint(vertices, endpoint, vertex_tolerance) {','function unique_vertex_for_endpoint(vertices, endpoint, vertex_tolerance) { const matches=[...vertices].filter(v=>Math.hypot(v.point.x-endpoint.x,v.point.y-endpoint.y)<=vertex_tolerance); if(matches.length>1)globalThis.auditTrace.push({kind:"ambiguous-endpoint",endpoint,vertex_tolerance,matches});');
 s=wrap(s,'public_error'  ,'globalThis.auditTrace.push({kind:"arrangement-error",error:args[0]}); return audit_original_public_error(...args);');
 s=wrap(s,'face_windings','const r=audit_original_face_windings(...args); if(r.constructor.name==="Error")globalThis.auditTrace.push({kind:"winding-error",result:r,dual:args[0],changes:args[1]});return r;');
 return s.replace(/(let \$\w* = size >= minimum_length;)/g,'$1\n if(size < minimum_length) globalThis.auditTrace.push({kind:"size-filter",size,minimum_length,segment:typeof segment!=="undefined"?segment:typeof first!=="undefined"?first:typeof child!=="undefined"?child.segment:null});');
});
edit('svg_path/csg.mjs',s=>s+'\nexport {csg_arrangement_build};\n');
if(process.env.AUDIT_DROP_REVERSED_SLIVERS==='1')edit('svg_path/internal/overlap_detection.mjs',s=>s.replace('merge_overlap_list(candidates.affine, tolerance)','merge_overlap_list($list.filter(candidates.affine, x=>!(x[1]-x[0]<1e-6 && Math.abs(x[3]-x[2])<1e-6)), tolerance)'));
if(process.env.AUDIT_PREFER_FULL_OVERLAP==='1')edit('svg_path/internal/overlap_detection.mjs',s=>s.replace('merge_overlap_list(candidates.affine, tolerance)','merge_overlap_list(globalThis.auditOverlapCandidates(candidates.affine), tolerance)'));
if(process.env.AUDIT_TRACE_OVERLAP_CONFLICTS==='1')edit('svg_path/internal/overlap_detection.mjs',s=>s.replace('let $3 = merge_overlap_list(candidates.affine, tolerance);','let $3 = merge_overlap_list(candidates.affine, tolerance);if(!($3 instanceof Ok))globalThis.auditTrace.push({kind:"overlap-merge-conflict",left,right,tolerance,candidates});'));
const id=Number(process.argv[2]??122);
let ticks=0,passes=0,deadline=Infinity,currentPair=null;
globalThis.auditTick=()=>{if((++ticks%1024)===0&&Date.now()>deadline)throw Error('Diagnostic time budget');};
globalThis.auditPair=(args)=>{currentPair={left:args[0],right:args[1],options:args[2]};};
globalThis.auditDiversity=(r,s,slots,sep,min)=>{passes++;if(passes%100===1)globalThis.lastDiversity={passes,remaining:[...r].length,selected:[...s].length,slots,sep,min};};
if(id===107)edit('svg_path/intersections.mjs',s=>{
 for(const name of ['segment_with','segment_without_overlap_precheck_with'])s=wrap(s,name,`globalThis.auditPair(args);const start=Date.now();const r=audit_original_${name}(...args);if(Date.now()-start>100)globalThis.auditTrace.push({kind:"pair-timing",stack:new globalThis.Error().stack,elapsedMs:Date.now()-start,left:args[0],right:args[1],result:r});return r;`);
 s=s.replaceAll('while (true) {','while (true) { globalThis.auditTick();');
 const anchor='    let remaining = loop$remaining;\n    let selected = loop$selected;\n    let slots = loop$slots;';
 if(s.split(anchor).length!==2)throw Error('Missing diversity anchor');
 return s.replace(anchor,anchor+'\n globalThis.auditDiversity(remaining,selected,slots,loop$separation,loop$minimum_separation);');
});
const imp=p=>import(pathToFileURL(path.join(scratch,'svg_path',p)));
const s=await imp('svg_path.mjs'),c=await imp('svg_path/csg.mjs'),a=await imp('svg_path/arrangement.mjs'),{toList,Ok}=await imp('gleam.mjs');
globalThis.auditOverlapCandidates=xs=>{const full=[...xs].find(x=>x[0]===0&&x[1]===1&&((x[2]===0&&x[3]===1)||(x[2]===1&&x[3]===0)));return full?toList([full]):xs;};
function clean(v){if(v&&typeof v==='object'){if(v[Symbol.iterator]&&!Array.isArray(v))return [...v].map(clean);if(Array.isArray(v))return v.map(clean);return {type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))};}return v;}
function operand(g){if(!g)return s.path_empty();return s.path_combine(toList(g.subpaths.filter(p=>p.curves.length).map(p=>{let sub=s.subpath_assert(toList(p.curves.map(v=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(v[i],v[i+1]))))));if(p.closed)sub=s.subpath_assert_close(sub);return s.subpath_as_path(sub);})));}
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'scripts/paperjs/booleans.json'))).fixtures;
const results=[];
const session=new inspector.Session();session.connect();const post=(m,p={})=>new Promise((resolve,reject)=>session.post(m,p,(e,r)=>e?reject(e):resolve(r)));
if(id===107){await post('Profiler.enable');await post('Profiler.start');}
for(const f of fixtures.filter(f=>process.argv[3]!==undefined?f.id===id:id===107?f.id===107:[122,123].includes(f.id))){
 const left=operand(f.left),right=operand(f.right),method={unite:'union_path_with',intersect:'intersection_path_with',subtract:'difference_path_with'}[f.op];
 for(const minimum of process.argv[3]!==undefined?[Number(process.argv[3])]:id===107?[1e-5]:[1e-5,1e-7,1e-9]){
  trace.length=0;const opts=c.default_options();opts.minimum_length=minimum;if(process.argv[4])opts.tolerance=Number(process.argv[4]);const start=Date.now();deadline=start+Number(process.env.AUDIT_BUDGET_MS??60000);let result;
  try{result=c[method](left,right,new s.Nonzero(),opts);}catch(e){result={diagnosticStop:String(e),stack:e.stack};}
  const row={id:f.id,minimum,tolerance:opts.tolerance,elapsedMs:Date.now()-start,result:clean(result),trace:clean(trace),ticks,diversity:globalThis.lastDiversity,currentPair:clean(currentPair)};
  if(id!==107&&!process.argv[4]){const b=c.csg_arrangement_build(toList([left,right]),opts);row.build=clean(b);if(b instanceof Ok)row.validation=clean(a.validate_closed_boundaries(b[0].graph,opts.tolerance,minimum));}
  results.push(row);console.log(f.id,minimum,row.elapsedMs,JSON.stringify(row.result).slice(0,250));
 }
}
if(id===107){const {profile}=await post('Profiler.stop');fs.writeFileSync(path.join(scratch,'profile.json'),JSON.stringify(profile));}
session.disconnect();fs.writeFileSync(path.join(scratch,'findings.json'),JSON.stringify({scratch,results},null,2)+'\n');console.log('Report: '+path.join(scratch,'findings.json'));
