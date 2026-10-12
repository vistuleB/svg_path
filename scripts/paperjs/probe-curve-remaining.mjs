import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as containment from '../../test_portable/build/dev/javascript/svg_path/svg_path/containment.mjs';
import {Ok} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const {blocks}=JSON.parse(fs.readFileSync(new URL('./curve-remaining.json',import.meta.url)));
function curve(c){return new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1])));}
function clean(v){return v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;}
const out=[];
for(const b of blocks)for(const [index,o] of b.operations.entries()){
 const c=curve(o.curve);let result;
 if(o.method==='getTimeAt'||o.method==='getLocationAt')result=measure.segment_parameter_at_length(c,o.args[0]);
 else if(o.method==='getTimeOf')result=distance.segment_projection(new s.Point(...o.args[0]),c);
 else if(o.method==='divideAt'||o.method==='divideAtTime'){
  const t=o.method==='divideAt'?measure.segment_parameter_at_length(c,o.args[0]):new Ok(o.args[0]);
  result=t instanceof Ok?s.segment_split(c,t[0]):t;
 }else if(o.method==='getTimesWithTangent'&&o.args.length){
  const p=[0,2,4].map(i=>new s.Point(3*(o.curve[i+2]-o.curve[i]),3*(o.curve[i+3]-o.curve[i+1])));
  result=containment.segment_ray_crossings(new s.QuadraticBezier(...p),new s.Point(0,0),new s.Point(...o.args[0]));
  if(result instanceof Ok)result=[...result[0]].map(pair=>pair[0]);
 }else continue;
 out.push({block:b.block,index,method:o.method,result:clean(result)});
}
fs.writeFileSync(new URL('./curve-remaining-screening.json',import.meta.url),JSON.stringify(out,null,2)+'\n');
console.log(out.filter(x=>x.block!==13));
