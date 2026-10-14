import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { optimize } from 'svgo';
import { transform2js, transformsMultiply, matrixToTransform } from './node_modules/svgo/plugins/_transforms.js';
import * as parse from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/parse.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform/serialize.mjs';
import * as transform from '../../test_portable/build/dev/javascript/svg_path/svg_path/transform.mjs';
const root = new URL('./', import.meta.url);
const fixtures = JSON.parse(fs.readFileSync(new URL('extra-fixtures.json', root))).filter(f => f.plugin === 'convertTransform');
const rows = [];
const maxDiff = (a,b) => Math.max(...a.map((x,i)=>Math.abs(x-b[i])));
function inspect(source, expected, precision) {
 let input = parse.attribute(source);
 const accepted = input.isOk();
 const tokens = transform2js(source);
 if (!accepted && tokens.length === 0) return { source, expected, accepted:false, classification:'strict-error-versus-invalid-transform-removal' };
 const adaptedSource = accepted ? source : tokens.map(x=>`${x.name}(${x.data.join(' ')})`).join(' ');
 if (!accepted) input = parse.attribute(adaptedSource);
 assert(input.isOk());
 const matrix = transform.to_tuple(input[0]);
 const reference = source.trim() ? transformsMultiply(transform2js(source)).data : [1,0,0,1,0,0];
 const parserError = maxDiff(matrix, reference);
 assert(parserError <= 1e-12 * Math.max(1,...matrix.map(Math.abs)), `Parser mismatch ${source}`);
 const actual = serialize.to_string_with(input[0], serialize.decimal_options(precision));
 const output = parse.attribute(actual);
 const expectedAccepted = parse.attribute(expected).isOk();
 const upstream = parse.attribute(transform2js(expected).map(x=>`${x.name}(${x.data.join(' ')})`).join(' '));
 assert(output.isOk() && upstream.isOk(), JSON.stringify({source,actual,expected,outputOk:output.isOk(),upstreamOk:upstream.isOk()}));
 const reconstructed = transform.to_tuple(output[0]);
 const error = maxDiff(matrix,reconstructed);
 for (const indices of [[0,1],[2,3],[4,5]]) {
   const budget = Math.max(1,...indices.map(i=>Math.abs(matrix[i]))) * Math.max(1e-12,10**-precision);
   assert(Math.max(...indices.map(i=>Math.abs(matrix[i]-reconstructed[i]))) <= budget * (1+1e-10), `Formatting budget exceeded ${source}: ${actual}`);
 }
 return {source,adaptedSource,expected,expectedAccepted,actual,accepted,precision,parserError,coefficientError:error,svgoCoefficientError:maxDiff(matrix,transform.to_tuple(upstream[0])),classification:!accepted || !expectedAccepted ? 'strict-separator-grammar-with-canonicalized-comparison' : actual===expected?'identical':'equivalent-factor-choice-and-rounding-policy'};
}
for (const f of fixtures) {
 const result = optimize(f.original,{plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;
 assert.equal(result.trim(),f.expected.trim()); // Upstream deliberately runs convertTransform only once.
 assert.equal(f.inputs.length,f.outputs.length);
 for (let i=0;i<f.inputs.length;i++) if ('transform' in f.inputs[i].attributes) {
   const row = inspect(f.inputs[i].attributes.transform,f.outputs[i].attributes.transform ?? '',f.params.transformPrecision ?? 5);
   if(row.classification === 'strict-error-versus-invalid-transform-removal') assert.equal(f.file,'convertTransform.04.svg.txt');
   rows.push({file:f.file,element:i,...row});
 }
}
let title, original;
vm.runInNewContext(fs.readFileSync(new URL('upstream/test/plugins/_transforms.test.js',root),'utf8').replace(/^import .*;\n/gm,''),{
 describe:(_name,fn)=>fn(),it:(name,fn)=>{title=name;fn();},
 matrixToTransform:(matrix,params)=>{original=matrix;return matrixToTransform(matrix,params);},
 expect:actual=>({toStrictEqual:expected=>{
   assert.equal(JSON.stringify(actual),JSON.stringify(expected));
   const source = `matrix(${original.data.join(' ')})`;
   const expectedText=expected.map(x=>`${x.name}(${x.data.join(' ')})`).join('');
   rows.push({test:title,...inspect(source,expectedText,5)});
 }})
},{timeout:5000});
fs.writeFileSync(new URL('transforms.json',root),JSON.stringify(rows,null,2)+'\n');
console.log(`${fixtures.length} fixtures; ${rows.length-2} transform attributes; 2 standalone matrix tests`);
