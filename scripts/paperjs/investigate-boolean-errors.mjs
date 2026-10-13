// Read-only production investigation. Instruments an isolated compiled JS copy.
// First: (cd test_paperjs && gleam build --target javascript)
// Usage: node scripts/paperjs/investigate-boolean-errors.mjs [fixture ids...]
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root = path.resolve(import.meta.dirname, '../..');
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'svg-boolean-audit-'));
fs.cpSync(path.join(root, 'test_paperjs/build/dev/javascript'), scratch, {recursive:true});
function edit(file, fn) {
  const p=path.join(scratch,'svg_path',file);
  fs.writeFileSync(p,fn(fs.readFileSync(p,'utf8')));
}
function replaceOnce(s, before, after) {
  if(s.split(before).length!==2) throw Error('Instrumentation anchor mismatch: '+before);
  return s.replace(before,after);
}
edit('svg_path/internal/overlap_detection.mjs',s=>{
  s=replaceOnce(s,'if ($2) {\n              return new Error(',
    'if ($2) {\n              globalThis.auditTrace.push({kind:"non-affine",left,right,tolerance,candidates});\n              return new Error(');
  return replaceOnce(s,'} else {\n                                  return new Error(\n                                    $svg_path.Error$NonAffineOverlapCorrespondence$const,',
    '} else {\n                                  globalThis.auditTrace.push({kind:"supplied-non-affine",left,right,tolerance,overlap});\n                                  return new Error(\n                                    $svg_path.Error$NonAffineOverlapCorrespondence$const,');
});
edit('svg_path.mjs',s=>replaceOnce(s,'export class CrossingMaxIterationsReached extends $CustomType {\n  constructor(estimate, value) {\n    super();',
  'export class CrossingMaxIterationsReached extends $CustomType {\n  constructor(estimate, value) {\n    super();\n    globalThis.auditTrace.push({kind:"crossing-error",estimate,value,context:globalThis.auditCrossing,stack:new globalThis.Error().stack});'));
edit('svg_path.mjs',s=>replaceOnce(s,'let upper = roots.head.isolation.upper;\n    return $result.try$(',
  'let upper = roots.head.isolation.upper;\n    globalThis.auditCrossing={segment,lower,estimate,upper,options,signed_line_distance_tolerance,controlValues:[segment.start,segment.control1,segment.control2,segment.end].filter(Boolean).map(crossing_function)};\n    return $result.try$('));
edit('svg_path/arrangement.mjs',s=>s.replace(/(let \$\w* = size >= minimum_length;)/g,
  '$1\n if (size < minimum_length) globalThis.auditTrace.push({kind:"size-filter",size,minimum_length,segment:typeof segment!=="undefined"?segment:typeof first!=="undefined"?first:typeof child!=="undefined"?child.segment:null});'));
edit('svg_path/csg.mjs',s=>{
  s=replaceOnce(s,'let ordered = _block;','let ordered = _block;\n      globalThis.auditTrace.push({kind:"rays",vertex,incoming_id,ordered});');
  return s+'\nexport {csg_arrangement_build,classify_boolean_edges, UnionOperation, IntersectionOperation, DifferenceOperation, SymmetricDifferenceOperation};\n';
});
const imp=p=>import(pathToFileURL(path.join(scratch,'svg_path',p)));
const s=await imp('svg_path.mjs'), c=await imp('svg_path/csg.mjs');
const {toList,Ok}=await imp('gleam.mjs');
function clean(v) {
  if(v&&typeof v==='object') {
    if(v[Symbol.iterator] && !Array.isArray(v)) return [...v].map(clean);
    if(Array.isArray(v)) return v.map(clean);
    return {type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))};
  } return v;
}
function operand(g) {
  if(!g)return s.path_empty();
  return s.path_combine(toList(g.subpaths.filter(p=>p.curves.length).map(p=>{
    let sub=s.subpath_assert(toList(p.curves.map(v=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(v[i],v[i+1]))))));
    if(p.closed)sub=s.subpath_assert_close(sub);
    return s.subpath_as_path(sub);
  })));
}
const data=JSON.parse(fs.readFileSync(path.join(root,'scripts/paperjs/booleans.json'))).fixtures;
const screen=JSON.parse(fs.readFileSync(path.join(root,'scripts/paperjs/boolean-screening-after-vertex-join.json'))).results;
const ids=process.argv.slice(2).map(Number);
const selected=ids.length?ids:screen.filter(x=>x.status==='library-error').map(x=>x.id);
const results=[];
for(const id of selected) {
  globalThis.auditTrace=[];
  const f=data.find(x=>x.id===id), left=operand(f.left),right=operand(f.right);
  const rule=f.left.fillRule==='evenodd'?new s.EvenOdd():new s.Nonzero();
  const fn={unite:c.union_path,intersect:c.intersection_path,subtract:c.difference_path,exclude:c.symmetric_difference_path,resolveCrossings:c.union_path}[f.op];
  const start=Date.now(),result=fn(left,right,rule);
  const trace=globalThis.auditTrace;
  let graph=null,boundary=null;
  if(result[0] instanceof c.InternalBoundaryTopologyError) {
    const b=c.csg_arrangement_build(toList([left,right]),c.default_options());
    if(b instanceof Ok) {
      graph=b[0].graph;
      const cls={unite:c.UnionOperation,intersect:c.IntersectionOperation,subtract:c.DifferenceOperation,exclude:c.SymmetricDifferenceOperation}[f.op];
      boundary=c.classify_boolean_edges(graph.edges,left,right,rule,new cls(),1e-6,toList([]));
    }
  }
  const entry={id,operation:f.op,result:clean(result),trace:clean(trace),graph:clean(graph),boundary:clean(boundary),elapsedMs:Date.now()-start};
  results.push(entry);
  console.log(id,result.constructor.name,result[0].constructor.name,entry.elapsedMs+'ms');
  fs.writeFileSync(path.join(scratch,'findings.json'),JSON.stringify({scratch,results},null,2)+'\n');
}
console.log('Report: '+path.join(scratch,'findings.json'));
