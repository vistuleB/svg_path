import fs from 'node:fs';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import { toList } from '../../test_portable/build/dev/javascript/prelude.mjs';
import { Some, None } from '../../test_portable/build/dev/javascript/gleam_stdlib/gleam/option.mjs';
import * as shapes from '../../test_portable/build/dev/javascript/svg_path/svg_path/basic_shapes.mjs';
import * as path from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root))).filter(f=>['convertShapeToPath','convertEllipseToCircle'].includes(f.plugin));
const rows=[];
for(const f of fixtures){
 let text=f.original;
 for(let n=0;n<2;n++){text=optimize(text,{plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;assert.equal(text.trim(),f.expected.trim());}
 let outputIndex=1;
 for(let i=1;i<f.inputs.length;i++){
  const {tag,attributes:a}=f.inputs[i];
  const row={file:f.file,element:i,tag,attributes:a};
  const num=(k,d=0)=>a[k]===undefined?d:Number(a[k]);
  if(['x','y','width','height','x1','y1','x2','y2'].some(k=>a[k]!==undefined&&!Number.isFinite(Number(a[k])))){
   row.classification='unit-resolution-outside-numeric-shape-api';outputIndex++;rows.push(row);continue;
  }
  let result, points;
  if(tag==='rect') result=shapes.rect(num('x'),num('y'),num('width'),num('height'),a.rx===undefined?new None():new Some(num('rx')),a.ry===undefined?new None():new Some(num('ry')));
  else if(tag==='line')result=shapes.line(num('x1'),num('y1'),num('x2'),num('y2'));
  else if(tag==='polyline'||tag==='polygon'){
   const nums=a.points.match(/[+-]?(?:\d*\.\d+|\d+\.?\d*)(?:e[+-]?\d+)?/gi).map(Number);
   if(nums.length%2){row.classification='malformed-points-attribute-outside-typed-api';rows.push(row);continue;}
   points=[];for(let j=0;j<nums.length;j+=2)points.push(new path.Point(nums[j],nums[j+1]));
   result=shapes[tag](toList(points));
  }else if(tag==='circle')result=shapes.circle(num('cx'),num('cy'),num('r'));
  else if(tag==='ellipse'){
   const rx=a.rx==='auto'?num('ry'):num('rx'),ry=a.ry==='auto'?num('rx'):num('ry');
   result=shapes.ellipse(num('cx'),num('cy'),rx,ry);
  }else throw Error(tag);
  const expected=f.outputs[outputIndex++];
  if(!result.isOk()){
   assert.equal(f.plugin,'convertEllipseToCircle');assert.equal(result[0].constructor.name,'DisabledRendering');
   row.classification='disabled-rendering-versus-zero-radius-element';rows.push(row);continue;
  }
  const sub=result[0], geometry=path.subpath_as_path(sub);
  const box=bounds.subpath_bounding_box(sub);assert(box.isOk());row.bounds=box[0];
  if(tag==='circle'||tag==='ellipse'){
   const rx=tag==='circle'?num('r'):a.rx==='auto'?num('ry'):num('rx');
   const ry=tag==='circle'?num('r'):a.ry==='auto'?num('rx'):num('ry');
   const expectedArea=Math.PI*rx*ry;
   assert(Math.abs(area.signed_subpath(sub)-expectedArea)<1e-10*Math.max(1,expectedArea));
   for(const segment of path.subpath_segments(sub))for(let j=0;j<=16;j++){
    const point=path.segment_point(segment,j/16);assert(point.isOk());
    const eq=((point[0].x-num('cx'))/rx)**2+((point[0].y-num('cy'))/ry)**2;
    assert(Math.abs(eq-1)<1e-12);
   }
   row.classification='same-ellipse-different-start-direction-and-segmentation';
  }else row.classification=expected.tag==='path'?'matching-linear-shape-with-formatting-differences':'rounded-rectangle-supported-but-svgo-retains-element';
  if(expected.attributes.d){
   const reference=parse.path(expected.attributes.d);assert(reference.isOk());
   const eb=bounds.path_bounding_box(reference[0]);assert(eb.isOk());
   row.expectedBounds=eb[0];
   row.boundsDifference=Math.max(...['min','max'].flatMap(k=>['x','y'].map(axis=>Math.abs(box[0][k][axis]-eb[0][k][axis]))));
   // Rounded endpoint arcs can amplify rounding; report rather than hide this.
   if ((tag==='circle'||tag==='ellipse') && row.boundsDifference > 0.001) row.classification='ellipse-traversal-and-rounded-semicircle-sensitivity';
   if(tag!=='circle'&&tag!=='ellipse') assert(row.boundsDifference<=0.00050000001);
  }
  row.actual=serialize.path_with(geometry,serialize.minifying_options(f.params.floatPrecision??3));
  assert(parse.path(row.actual).isOk());rows.push(row);
 }
 assert.equal(outputIndex,f.outputs.length);
}
fs.writeFileSync(new URL('shapes.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures; ${rows.length} shape elements reviewed`);
