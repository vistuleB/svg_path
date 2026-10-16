import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
const root=new URL('.',import.meta.url).pathname;
const corpus=JSON.parse(fs.readFileSync(root+'fl006-benchmark-corpus.json')).pairs;
const report=JSON.parse(fs.readFileSync(root+'remaining-fl006-benchmark.json'));
const p=x=>new g.Point(x.x,x.y);
const seg=s=>s.kind==='CubicBezier'?new g.CubicBezier(p(s.start),p(s.control1),p(s.control2),p(s.end)):s.kind==='QuadraticBezier'?new g.QuadraticBezier(p(s.start),p(s.control),p(s.end)):new g.Arc(p(s.start),p(s.radius),s.x_axis_rotation,s.large_arc,s.sweep,p(s.end));
const changed=[];
for(const r of report.rows.slice(0,-1)){
 if(r.baseline.hits?.length===r.candidate.hits?.length)continue;
 const input=corpus[r.index],a=seg(input.left),b=seg(input.right);
 const measure=h=>{const u=g.segment_point(a,h.left_t)[0],v=g.segment_point(b,h.right_t)[0],du=g.segment_derivative(a,h.left_t)[0],dv=g.segment_derivative(b,h.right_t)[0];return {left_t:h.left_t,right_t:h.right_t,separation:Math.hypot(u.x-v.x,u.y-v.y),normalizedTangentCross:Math.abs(du.x*dv.y-du.y*dv.x)/(Math.hypot(du.x,du.y)*Math.hypot(dv.x,dv.y))};};
 changed.push({index:r.index,tolerance:input.options.tolerance,baseline:r.baseline.hits.map(measure),candidate:r.candidate.hits.map(measure)});
}
fs.writeFileSync(root+'remaining-fl006-result-changes.json',JSON.stringify(changed,null,2)+'\n');
console.log(changed.map(x=>({index:x.index,counts:[x.baseline.length,x.candidate.length],maxSeparation:Math.max(...x.candidate.map(h=>h.separation)),maxNearEndpointTangentCross:Math.max(...x.candidate.filter(h=>h.left_t<.001||h.left_t>.999).map(h=>h.normalizedTangentCross))})));
