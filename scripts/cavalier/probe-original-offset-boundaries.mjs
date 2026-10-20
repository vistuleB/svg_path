import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as d from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as m from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
const ok=r=>{if(!r.isOk())throw r[0];return r[0]},P=a=>new g.Point(a[0],a[1]);
const revive=s=>s.type==='Arc'?new g.Arc(s.start,s.radius,s.x_axis_rotation,s.large_arc,s.sweep,s.end):new g.Line(s.start,s.end);
function segs(p){return p.vertices.slice(0,p.closed?p.vertices.length:p.vertices.length-1).map((v,i)=>{const w=p.vertices[(i+1)%p.vertices.length],a=P(v),b=P(w);if(!v[2])return new g.Line(a,b);const r=Math.hypot(b.x-a.x,b.y-a.y)*(1+v[2]*v[2])/(4*Math.abs(v[2]));return new g.Arc(a,new g.Point(r,r),0,Math.abs(v[2])>1,v[2]>0,b)})}
const cases=JSON.parse(fs.readFileSync(new URL('./original-offset-specific-cases.json',import.meta.url)));
const upstream=fs.readFileSync(new URL('./original-offset-specific-upstream.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
for(const id of (process.env.AUDIT_UNTRIMMED?['CC01499','CC01504']:['CC01405','CC01470','CC01499','CC01504'])){
 const c=cases.find(c=>c.id===id),us=upstream.find(c=>c.id===id).paths.map(segs),source=segs(c.input);
 const file=process.env.AUDIT_UNTRIMMED?`original-offset-${id}-untrimmed.json`:id==='CC01405'?'original-offset-case11-detail.json':`original-offset-${id}-tight.json`;
 const native=JSON.parse(fs.readFileSync(new URL('./'+file,import.meta.url)))[0].result.map(s=>s.segments.map(revive));
 const distance=(p,ss)=>Math.min(...ss.map(s=>ok(d.segment_distance(p,s))));
 const sample=(paths,other)=>paths.map(ss=>ss.map((s,index)=>{const samples=[.1,.25,.5,.75,.9].map(t=>{const p=ok(g.segment_point(s,t));return {t,point:p,toOther:distance(p,other.flat()),toSource:distance(p,source)}});return {index,type:s.constructor.name,length:ok(m.segment_length(s)),samples}}));
 console.log(JSON.stringify({id,native:sample(native,us),upstream:sample(us,native)}));
}
