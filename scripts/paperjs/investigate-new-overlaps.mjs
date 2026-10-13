// Read-only production investigation. Instruments an isolated compiled JS copy.
// First: (cd test_paperjs && gleam build --target javascript)
// Usage: node scripts/paperjs/investigate-new-overlaps.mjs [fixture ids...]
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
const ids=process.argv.slice(2).map(Number);
const selected=ids.length?ids:[128,129,130,131];
const results=[];
for(const id of selected) {
  globalThis.auditTrace=[];
  const f=data.find(x=>x.id===id), left=operand(f.left),right=operand(f.right);
  const rule=f.left.fillRule==='evenodd'?new s.EvenOdd():new s.Nonzero();
  const fn={unite:c.union_path,intersect:c.intersection_path,subtract:c.difference_path,exclude:c.symmetric_difference_path,resolveCrossings:c.union_path}[f.op];
  const start=Date.now(),result=fn(left,right,rule);
  const trace=globalThis.auditTrace;
  const entry={id,operation:f.op,result:clean(result),trace:clean(trace),elapsedMs:Date.now()-start};
  results.push(entry);
  console.log(id,result.constructor.name,result[0].constructor.name,entry.elapsedMs+'ms');
  fs.writeFileSync(path.join(scratch,'findings.json'),JSON.stringify({scratch,results},null,2)+'\n');
}
console.log('Report: '+path.join(scratch,'findings.json'));
