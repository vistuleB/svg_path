// Fixed curve-pair corpus; separate generated runtimes, alternating warm batches.
import fs from 'node:fs';
import os from 'node:os';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const [baselineDir,candidateDir,output]=process.argv.slice(2);
if(!output)throw Error('Usage: node benchmark-fl006.mjs BASELINE_RUNTIME CANDIDATE_RUNTIME OUTPUT');
const corpus=JSON.parse(fs.readFileSync(new URL('fl006-benchmark-corpus.json',import.meta.url))).pairs;
const fl006=JSON.parse(fs.readFileSync(new URL('remaining-continuity-4295-pair.json',import.meta.url)));
corpus.push({left:{kind:'Arc',...fl006.curved},right:{kind:'Arc',...fl006.cutter},options:{tolerance:1e-7,max_depth:48},label:'FL006'});
const runtimes=[];
for(const dir of [baselineDir,candidateDir]){
 const root=pathToFileURL(`${dir}/`).href;
 const g=await import(`${root}svg_path/svg_path.mjs`),ix=await import(`${root}svg_path/svg_path/intersections.mjs`);
 const point=p=>new g.Point(p.x,p.y);
 const segment=s=>s.kind==='Arc'?new g.Arc(point(s.start),point(s.radius),s.x_axis_rotation,s.large_arc,s.sweep,point(s.end)):s.kind==='CubicBezier'?new g.CubicBezier(point(s.start),point(s.control1),point(s.control2),point(s.end)):s.kind==='QuadraticBezier'?new g.QuadraticBezier(point(s.start),point(s.control),point(s.end)):new g.Line(point(s.start),point(s.end));
 const inputs=corpus.map(p=>[segment(p.left),segment(p.right),Object.assign(ix.default_options(),p.options,{parameter_snap:new ix.NoParameterSnap()})]);
 runtimes.push({ix,inputs});
}
const summarize=r=>r.isOk()?{ok:true,hits:[...r[0]]}:{ok:false,error:r[0].constructor.name,details:r[0]};
function run(which){const r=runtimes[which],times=[],results=[];let total=performance.now();for(const input of r.inputs){const start=performance.now();let result;try{result=summarize(r.ix.segment_with(...input));}catch(e){result={thrown:String(e)};}times.push(performance.now()-start);results.push(result);}return {total:performance.now()-total,times,results};}
run(0);run(1); // Untimed warm-up for both runtimes.
const rounds=[];
for(let i=0;i<7;i++){const order=i%2?[1,0]:[0,1],row=[];for(const which of order)row[which]=run(which);rounds.push(row);console.log('round',i+1,row.map(r=>r.total));}
const median=a=>a.toSorted((a,b)=>a-b)[Math.floor(a.length/2)];
const rows=corpus.map((input,i)=>({index:i,label:input.label,baselineMs:median(rounds.map(r=>r[0].times[i])),candidateMs:median(rounds.map(r=>r[1].times[i])),baseline:rounds[0][0].results[i],candidate:rounds[0][1].results[i]}));
const hash=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const report={runtimeHashes:[baselineDir,candidateDir].map(d=>hash(`${d}/svg_path/svg_path/intersections.mjs`)),corpusHash:hash(new URL('fl006-benchmark-corpus.json',import.meta.url)),date:new Date().toISOString(),node:process.version,platform:process.platform,arch:process.arch,cpu:os.cpus()[0].model,pairs:corpus.length,rounds:rounds.map(r=>r.map(x=>x.total)),medianTotals:[0,1].map(i=>median(rounds.map(r=>r[i].total))),rows};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log('median totals',report.medianTotals);
