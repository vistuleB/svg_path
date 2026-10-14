import fs from 'node:fs';
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from './probe/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const source=JSON.parse(fs.readFileSync(new URL('tangent-fixtures.json',import.meta.url)));
const segment=p=>new [null,null,g.Line,g.QuadraticBezier,g.CubicBezier][p.length](...p.map(q=>new g.Point(...q)));
const rows=[];
for(const r of source){
 const a=segment(r.left),b=segment(r.right);
 const result=ix.segment(a,b);
 const reverse=ix.segment(b,a);
 const pack=r=>r.isOk()?{ok:true,values:[...r[0]]}:{ok:false,error:r[0].constructor.name};
 rows.push({...r,current:pack(result),reverse:pack(reverse)});
 console.log(r.call,JSON.stringify(pack(result)));
}
const sweeps=[];
for(const call of [1268,1622,1714]){
 const r=source.find(r=>r.call===call);
 for(const tolerance of [1e-9,1e-12,1e-14]){
  const options=new ix.IntersectionOptions(tolerance,48,new ix.NoParameterSnap());
  const result=ix.segment_with(segment(r.left),segment(r.right),options);
  sweeps.push({call,tolerance,result:result.isOk()?[...result[0]]:result[0].constructor.name});
 }
}
fs.writeFileSync(new URL('tangent-investigation.json',import.meta.url),JSON.stringify({rows,sweeps},null,2)+'\n');
console.log('sweeps',JSON.stringify(sweeps));
