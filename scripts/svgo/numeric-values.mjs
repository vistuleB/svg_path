import fs from 'node:fs';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root))).filter(f=>['cleanupNumericValues','cleanupListOfValues'].includes(f.plugin));
const rows=[];
const numbers=s=>[...s.matchAll(/[+-]?(?:\d*\.\d+|\d+\.?\d*)(?:e[+-]?\d+)?(?:px|pt|in|em|%)?/gi)].map(m=>{const n=parseFloat(m[0]);return {value:n,unit:m[0].replace(/^[+-]?(?:\d*\.\d+|\d+\.?\d*)(?:e[+-]?\d+)?/i,'')};});
for(const f of fixtures){
 let text=f.original;for(let n=0;n<2;n++){text=optimize(text,{plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;assert.equal(text.trim(),f.expected.trim());}
 assert.equal(f.inputs.length,f.outputs.length);
 for(let i=0;i<f.inputs.length;i++)for(const [name,value] of Object.entries(f.inputs[i].attributes)){
  const expected=f.outputs[i].attributes[name];
  if(expected===value)continue;
  const before=numbers(value),after=numbers(expected);assert.equal(before.length,after.length);
  for(let j=0;j<before.length;j++){
   const a=before[j],b=after[j];
   if(['in','pt'].includes(a.unit)) {rows.push({file:f.file,element:i,attribute:name,token:j,source:a,expected:b,classification:'physical-unit-conversion-outside-number-formatting'});continue;}
   const geometry=path.subpath_as_path(path.subpath_empty(new path.Point(a.value,0)));
   const output=serialize.path_with(geometry,serialize.decimal_options(f.params.floatPrecision??3));
   const parsed=parse.path(output);assert(parsed.isOk());
   const actual=path.subpath_start([...path.path_subpaths(parsed[0])][0]).x;
   assert(Math.abs(actual-b.value)<=1e-12*Math.max(1,Math.abs(actual)));
   rows.push({file:f.file,element:i,attribute:name,token:j,source:a,expected:b,actual,classification:'numeric-rounding-agrees-attribute-policy-separate'});
  }
 }
}
fs.writeFileSync(new URL('numeric-values.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures; ${rows.length} changed-attribute numeric tokens reviewed`);
