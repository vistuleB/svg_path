import fs from 'node:fs';
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from './probe/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const make=ps=>new [null,null,g.Line,g.QuadraticBezier,g.CubicBezier][ps.length](...ps.map(p=>new g.Point(...p)));
const evaluate=(ps,t)=>{while(ps.length>1)ps=ps.slice(0,-1).map((p,i)=>p.map((x,k)=>(1-t)*x+t*ps[i+1][k]));return ps[0];};
const reference=JSON.parse(fs.readFileSync(new URL('almost-collinear-fixture.json',import.meta.url)));
const all=JSON.parse(fs.readFileSync(new URL('intersections-results.json',import.meta.url))).rows;
const chosen=all.filter(r=>r.status==='matches-at-diagnostic-tolerance'&&r.left.length>=3&&r.right.length>=3&&r.reference.length&&r.reference.every(x=>x.kind!==5)).filter((r,i)=>i%37===0).slice(0,24);
const cases=[{name:'FI004',left:reference.left,right:reference.right,reference:reference.reference,tolerance:1e-12},...chosen.map(r=>({name:`compressed-${r.call}`,left:r.left.map(([x,y])=>[x,y*1e-12]),right:r.right.map(([x,y])=>[x,y*1e-12]),reference:r.reference,tolerance:1e-9})),{name:'near-miss',left:[[0,0],[.5,0],[1,0]],right:[[0,1e-12],[.5,1e-12],[1,1e-12]],reference:[],tolerance:1e-9}];
const rows=[];
for(const c of cases){
 const points=[...c.left,...c.right],min=[0,1].map(k=>Math.min(...points.map(p=>p[k]))),span=[0,1].map(k=>Math.max(...points.map(p=>p[k]))-min[k]);
 if(span.some(x=>x===0||!Number.isFinite(x)))continue;
 const normalized=ps=>ps.map(p=>p.map((x,k)=>(x-min[k])/span[k]));
 const opts=new ix.IntersectionOptions(c.tolerance,48,new ix.NoParameterSnap());
 const nopts=new ix.IntersectionOptions(1e-12,48,new ix.NoParameterSnap());
 const start=performance.now(),raw=ix.elizabeth_beam_intersections(make(c.left),make(c.right),opts),normal=ix.elizabeth_beam_intersections(make(normalized(c.left)),make(normalized(c.right)),nopts);
 const pairs=r=>r.isOk()?[...r[0].intersections]:[];
 const valid=p=>{const a=evaluate(c.left,p.left_t),b=evaluate(c.right,p.right_t);return Math.hypot(a[0]-b[0],a[1]-b[1])<=c.tolerance;};
 const baseline=pairs(raw).filter(valid),seeds=pairs(normal).filter(valid);
 const matches=ps=>c.reference.filter(r=>ps.some(p=>Math.max(Math.abs(p.left_t-r.t1),Math.abs(p.right_t-r.t2))<=1e-7)).length;
 const row={name:c.name,reference:c.reference.length,baseline:baseline.length,normalized:seeds.length,baselineMatches:matches(baseline),normalizedMatches:matches(seeds),normalizedRejected:pairs(normal).length-seeds.length,rawError:raw.isOk()?null:raw[0].constructor.name,normalizedError:normal.isOk()?null:normal[0].constructor.name,ms:performance.now()-start};
 rows.push(row);console.log(row);
}
fs.writeFileSync(new URL('preconditioning-experiment.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
