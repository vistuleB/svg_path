import fs from 'node:fs';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as shapes from '../../test_portable/build/dev/javascript/svg_path/svg_path/basic_shapes.mjs';
import { None } from '../../test_portable/build/dev/javascript/gleam_stdlib/gleam/option.mjs';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root))).filter(f=>['reusePaths','removeHiddenElems','removeUselessStrokeAndFill'].includes(f.plugin));
const rows=[];
for(const f of fixtures){
 let text=f.original;for(let n=0;n<2;n++){text=optimize(text,{path:`test/plugins/${f.file}`,plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;assert.equal(text.trim(),f.expected.trim());}
 const checks=[];
 for(const [i,node] of f.inputs.entries()){
  if(node.tag==='path'){
   const text=node.attributes.d??'';const result=parse.path(text);
   const malformed=['z','M 50 50 L 0'].includes(text);
   assert.equal(result.isOk(),!malformed);
   checks.push({element:i,kind:'parse',accepted:result.isOk(),classification:malformed?'strict-error-versus-removal':'path-geometry-independent-of-visibility-or-reference-policy'});
  }
  if(f.file==='removeHiddenElems.03.svg.txt'&&node.tag==='circle'){
   const result=shapes.circle(Number(node.attributes.cx??0),Number(node.attributes.cy??0),0);assert(!result.isOk());assert.equal(result[0].constructor.name,'DisabledRendering');checks.push({element:i,kind:'disabled-circle',classification:'static-geometry-not-animation-policy'});
  }
  if(f.file==='removeHiddenElems.04.svg.txt'&&node.tag==='ellipse'){
   const result=shapes.ellipse(0,0,0,0);assert(!result.isOk());assert.equal(result[0].constructor.name,'DisabledRendering');checks.push({element:i,kind:'disabled-ellipse'});
  }
  if(f.file==='removeHiddenElems.05.svg.txt'&&node.tag==='rect'){
   const result=shapes.rect(0,0,0,0,new None(),new None());assert(!result.isOk());assert.equal(result[0].constructor.name,'DisabledRendering');checks.push({element:i,kind:'disabled-rectangle'});
  }
 }
 rows.push({file:f.file,classification:'document-rendering-and-reference-policy',checks});
}
fs.writeFileSync(new URL('secondary.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures reviewed; ${rows.reduce((n,r)=>n+r.checks.length,0)} applicable parsing/static-shape checks`);
