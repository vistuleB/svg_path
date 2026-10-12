import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as curvature from '../../test_portable/build/dev/javascript/svg_path/svg_path/curvature.mjs';
import {Ok} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const {fixtures}=JSON.parse(fs.readFileSync(new URL('./curves.json',import.meta.url)));
const unwrap=r=>{if(!(r instanceof Ok))throw r;return r[0]};
function clean(v){return v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;}
const results=[];
for(const f of fixtures) {
 const c=new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(f.curve[i],f.curve[i+1])));
 let actual, status, tolerance = 1e-8;
 try {
  const t=f.args[0];
  switch(f.method) {
   case 'getPointAtTime': {const p=unwrap(s.segment_point(c,t));actual=f.component?p[f.component]:[p.x,p.y];tolerance=f.component?0:1e-5;break;}
   case 'getTangentAtTime': case 'getWeightedTangentAtTime':
   case 'getNormalAtTime': case 'getWeightedNormalAtTime': {
    const p=unwrap(s.segment_derivative(c,t));
    let x=p.x,y=p.y;
    if(f.method.includes('Normal')) [x,y]=[y,-x];
    if(!f.method.includes('Weighted')) {const n=Math.hypot(x,y);x/=n;y/=n;}
    actual=[x,y];tolerance=f.method.includes('Weighted')?1e-5:1e-7;break;
   }
   case 'getCurvatureAtTime': actual=-unwrap(curvature.segment_left_normal_curvature(c,t));tolerance=1e-12;break;
   case 'getTimeAt': actual=unwrap(measure.segment_parameter_at_length(c,t));tolerance=1e-8;break;
   case 'getPartLength': actual=unwrap(measure.segment_length(unwrap(s.segment_between(c,t,f.args[1]))));tolerance=1e-8;break;
  }
  const a=Array.isArray(actual)?actual:[actual], e=Array.isArray(f.expected)?f.expected:[f.expected];
  const error=Math.max(...a.map((v,i)=>Math.abs(v-e[i])));
  status=Number.isFinite(error)&&error<=tolerance?'match':'discrepancy';
  results.push({id:f.id,block:f.block,method:f.method,status,expected:f.expected,actual,error,tolerance});
 } catch(error) { results.push({id:f.id,block:f.block,method:f.method,status:'library-error',error:clean(error)}); }
}
fs.writeFileSync(new URL('./curve-screening.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
console.log(results.reduce((a,r)=>(a[r.status]=(a[r.status]||0)+1,a),{}));
console.log(results.filter(r=>r.status!=='match'));
