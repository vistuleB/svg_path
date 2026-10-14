import fs from 'node:fs';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as t from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
import * as tp from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/parse.mjs';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root))).filter(f=>f.plugin==='removeOffCanvasPaths');
const rows=[];
for(const f of fixtures){
 let text=f.original;for(let n=0;n<2;n++){text=optimize(text,{plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;assert.equal(text.trim(),f.expected.trim());}
 const a=f.inputs[0].attributes;
 const view=a.viewBox?a.viewBox.split(/[,\s]+/).map(Number):a.width&&a.height?[0,0,Number(a.width),Number(a.height)]:null;
 for(const [i,node] of f.inputs.entries())if(node.tag==='path'){
  const source=parse.path(node.attributes.d);assert(source.isOk());
  let matrix=t.identity();
  for(const attrs of [...node.ancestors,node.attributes])if(attrs.transform){const parsed=tp.attribute(attrs.transform);assert(parsed.isOk());matrix=t.multiply(matrix,parsed[0]);}
  const transformed=t.path(source[0],matrix);assert(transformed.isOk());
  const box=bounds.path_bounding_box(transformed[0]);assert(box.isOk());
  const b=box[0];
  const overlap=view?b.max.x>=view[0]&&b.min.x<=view[0]+view[2]&&b.max.y>=view[1]&&b.min.y<=view[1]+view[3]:null;
  const retained=f.outputs.some(n=>n.tag==='path'&&JSON.stringify(n.attributes)===JSON.stringify(node.attributes));
  if(view)assert.equal(overlap,retained,`${f.file}:${i}`);else assert(retained);
  rows.push({file:f.file,element:i,bounds:b,viewport:view,boundsOverlap:overlap,retained,classification:view?'bounds-consistent-with-fixture-culling':'no-viewport-no-culling-contract'});
 }
}
fs.writeFileSync(new URL('off-canvas.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures; ${rows.length} paths; viewport/bounds decisions agree where defined`);
