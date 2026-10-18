import fs from 'node:fs';
import * as g from '/tmp/cavalier-cyclic-trace/svg_path/svg_path.mjs';
import * as ar from '/tmp/cavalier-cyclic-trace/svg_path/svg_path/arrangement.mjs';
import {toList} from '/tmp/cavalier-cyclic-trace/prelude.mjs';
const c=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url))).find(c=>c.id==='CC01059');
function segments(p){return p.vertices.map((a,i)=>{const b=p.vertices[(i+1)%p.vertices.length],start=new g.Point(a[0],a[1]),end=new g.Point(b[0],b[1]);if(!a[2])return new g.Line(start,end);const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+a[2]*a[2])/(4*Math.abs(a[2]));return new g.Arc(start,new g.Point(r,r),0,Math.abs(a[2])>1,a[2]>0,end);});}
const r=ar.build_with(toList([...segments(c.input),...segments(c.other)]),1e-6,1e-8,0);
console.log(JSON.stringify({id:c.id,result:r.isOk()?{ok:true}:{error:{type:r[0].constructor.name,...r[0]}},trace:globalThis.cyclicTrace},null,2));
