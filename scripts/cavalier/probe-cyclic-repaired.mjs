import fs from 'node:fs';
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as ar from './probe/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import {toList} from './probe/build/dev/javascript/prelude.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url))).filter(c=>c.id==='CC01059'||(c.id>='CC01063'&&c.id<='CC01077'));
const results=[];
function segments(p){return p.vertices.map((a,i)=>{const b=p.vertices[(i+1)%p.vertices.length],start=new g.Point(a[0],a[1]),end=new g.Point(b[0],b[1]);if(!a[2])return new g.Line(start,end);const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+a[2]*a[2])/(4*Math.abs(a[2]));return new g.Arc(start,new g.Point(r,r),0,Math.abs(a[2])>1,a[2]>0,end);});}
for(const c of cases){
const r=ar.build_with(toList([...segments(c.input),...segments(c.other)]),1e-6,1e-8,0);
results.push({id:c.id,result:r.isOk()?{ok:true}:{error:{type:r[0].constructor.name,...r[0]}}});
}
console.log(JSON.stringify(results,null,2));
