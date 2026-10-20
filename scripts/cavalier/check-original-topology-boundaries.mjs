// Diagnostic sampled boundary sets: ignores traversal multiplicity and grouping.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as overlaps from '../../test_portable/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
import * as d from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as m from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const read=n=>JSON.parse(fs.readFileSync(new URL(n,import.meta.url))),lines=n=>fs.readFileSync(new URL(n,import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const ok=r=>{if(!r.isOk())throw r[0];return r[0]},P=a=>new g.Point(a[0],a[1]);
const cases=read('./original-offset-topology-cases.json'), unique=read('./original-offset-topology-unique.json'),up=lines('./original-offset-topology-upstream.jsonl'),native=lines('./original-offset-topology-geometry.jsonl');
const key=c=>JSON.stringify([c.input,c.offset]),ids=new Map(unique.map(c=>[key(c),c.id]));
const revive=s=>s.type==='Arc'?new g.Arc(s.start,s.radius,s.x_axis_rotation,s.large_arc,s.sweep,s.end):new g.Line(s.start,s.end);
function segs(p){return p.vertices.slice(0,p.closed?p.vertices.length:p.vertices.length-1).map((v,i)=>{const w=p.vertices[(i+1)%p.vertices.length],a=P(v),b=P(w);if(!v[2])return new g.Line(a,b);const r=Math.hypot(b.x-a.x,b.y-a.y)*(1+v[2]*v[2])/(4*Math.abs(v[2]));return new g.Arc(a,new g.Point(r,r),0,Math.abs(v[2])>1,v[2]>0,b)})}
function directed(ss,other){let maxDistance=0,missed=0,points=0,witness=null;for(const s of ss)for(const t of [0,.125,.25,.5,.75,.875,1]){const p=ok(g.segment_point(s,t)),distance=other.length?Math.min(...other.map(o=>ok(d.segment_distance(p,o)))):Infinity;points++;if(distance>1e-5)missed++;if(distance>maxDistance){maxDistance=distance;witness=p}}return {points,missed,maxDistance:Number.isFinite(maxDistance)?maxDistance:null,noTarget:other.length===0&&ss.length>0,witness}}
function unionLength(ss){let total=0;for(let i=0;i<ss.length;i++){const intervals=[];for(let j=0;j<i;j++)for(const o of ok(overlaps.segment(ss[i],ss[j])))intervals.push([o.left_from,o.left_to]);intervals.sort((a,b)=>a[0]-b[0]);let end=0,covered=0;for(const [a,b] of intervals){if(b>end)covered+=b-Math.max(a,end);end=Math.max(end,b)}total+=ok(m.segment_length(ss[i]))*(1-covered)}return total}
for(const c of cases){try{
 const n=native.find(n=>n.id===ids.get(key(c)));if(!n?.geometry){console.log(JSON.stringify({id:c.id,status:'native-unavailable',native:n?.status}));continue}
 const nativePaths=n.geometry.map(ss=>ss.map(revive)),upPaths=up.find(u=>u.id===c.id).paths.map(segs);
 const source=segs(c.input),a=directed(nativePaths.flat(),upPaths.flat()),b=directed(upPaths.flat(),nativePaths.flat());
 const upProps=upPaths.map((ss,i)=>{const s=ok(g.subpath(toList(ss))),box=ok(bounds.subpath_bounding_box(s));return {length:ok(m.subpath_length(s)),area:up.find(u=>u.id===c.id).paths[i].closed?area.signed_subpath(s):0,bounds:[box.min.x,box.min.y,box.max.x,box.max.y]}});
 const exportMatches=upProps.length===c.result.length&&upProps.every((p,i)=>Math.abs(p.length-c.result[i].length)<1e-4&&Math.abs(p.area-c.result[i].area)<1e-4&&p.bounds.every((v,j)=>Math.abs(v-c.result[i].bounds[j])<1e-4));
 const rawCrossing=['CC01738','CC01739'].includes(c.id)?read('./original-topology-crossing-untrimmed.json')[0].result.flatMap(p=>p.segments.map(revive)):null;
 const upstreamToUntrimmed=rawCrossing?directed(upPaths.flat(),rawCrossing):null;
 const witnessSourceDistance=a.witness?Math.min(...source.map(s=>ok(d.segment_distance(a.witness,s)))):null;
 console.log(JSON.stringify({id:c.id,test:c.test,policy:c.options,nativeId:n.id,nativeContours:nativePaths.length,upstreamContours:upPaths.length,nativeLength:n.actual.reduce((s,p)=>s+p.length,0),upstreamLength:c.result.reduce((s,p)=>s+p.length,0),nativeToUpstream:a,upstreamToNative:b,witnessSourceDistance,upstreamToUntrimmed,nativeBoundaryUnionLength:unionLength(nativePaths.flat()),upstreamBoundaryUnionLength:unionLength(upPaths.flat()),upstreamExportPropertiesMatch:exportMatches,status:!a.missed&&!b.missed?'sampled-boundary-set-match':'sampled-boundary-difference'}));
}catch(e){console.log(JSON.stringify({id:c.id,status:'error',error:{type:e.constructor?.name,...e}}))}}
