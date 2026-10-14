import fs from 'node:fs';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import { toList } from '../../test_portable/build/dev/javascript/prelude.mjs';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root))).filter(f=>f.plugin==='mergePaths');
const rows=[];
function compare(a,b){
 if(typeof a==='number'){assert(Math.abs(a-b)<=1e-10*Math.max(1,Math.abs(a),Math.abs(b)),`${a} != ${b}`);return;}
 if(typeof a!=='object'||a===null){assert.equal(a,b);return;}
 assert.deepEqual(Object.keys(a),Object.keys(b));for(const k of Object.keys(a))compare(a[k],b[k]);
}
function parsed(nodes){return nodes.filter(n=>'d'in n.attributes).map(n=>{const r=parse.path(n.attributes.d);assert(r.isOk());return r[0];});}
function nonempty(p){return [...path.path_subpaths(p)].filter(s=>[...path.subpath_segments(s)].length>0);}
for(const f of fixtures){

 let text=f.original;for(let n=0;n<2;n++){text=optimize(text,{plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;assert.equal(text.trim(),f.expected.trim());}
 const input=parsed(f.inputs),output=parsed(f.outputs);
 const combined=path.path_combine(toList(input));
 assert.equal([...path.path_subpaths(combined)].length,input.reduce((n,p)=>n+[...path.path_subpaths(p)].length,0));
 const expected=path.path_combine(toList(output));

 compare(JSON.parse(JSON.stringify(nonempty(combined))),JSON.parse(JSON.stringify(nonempty(expected))));
 const actual=serialize.path_with(combined,serialize.minifying_options(8)),roundtrip=parse.path(actual);assert(roundtrip.isOk());

 const closures=[];
 const before=[...path.path_subpaths(combined)], after=[...path.path_subpaths(roundtrip[0])];
 assert.equal(before.length,after.length);
 for(let i=0;i<before.length;i++){
  const a=[...path.subpath_segments(before[i])], b=[...path.subpath_segments(after[i])];
  assert.equal(path.subpath_is_closed(before[i]),path.subpath_is_closed(after[i]));
  compare(path.subpath_start(before[i]),path.subpath_start(after[i]));
  if(b.length===a.length+1){
   const last=b.at(-1);assert(last instanceof path.Line);assert(path.subpath_is_closed(after[i]));
   const length=Math.hypot(last.end.x-last.start.x,last.end.y-last.start.y);
   assert(length<=1e-10);closures.push({subpath:i,length});b.pop();
  }
  assert.equal(a.length,b.length);compare(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(b)));
 }
 rows.push({file:f.file,inputPaths:input.length,outputPaths:output.length,inputSubpaths:[...path.path_subpaths(combined)].length,outputSubpaths:[...path.path_subpaths(expected)].length,nonemptyGeometryMatches:true,combinedRoundtrip:true,roundtripClosingSegments:closures,classification:'document-merge-policy-not-boolean-union',actual});
}
fs.writeFileSync(new URL('merge-paths.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures; ${rows.reduce((n,r)=>n+r.inputPaths,0)} input paths; nonempty geometry and combination round trips verified`);
