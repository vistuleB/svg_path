// Independent geometric references for bounds fixtures 10/42 and 75.
// Does not call Paper or Gleam for source extrema or miter intersections.
import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as stroke from '../../test_portable/build/dev/javascript/svg_path/svg_path/stroke.mjs';
import * as offset from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import {Ok,toList} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const fixtures=JSON.parse(fs.readFileSync(new URL('./bounds.json',import.meta.url))).fixtures;
const unwrap=r=>{if(!(r instanceof Ok))throw r;return r[0];};
const clean=v=>v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;
function roots(ps,k){const [p,q,r,t]=ps.map(p=>p[k]);const a=-p+3*q-3*r+t,b=2*(p-2*q+r),c=q-p;if(a===0)return b===0?[]:[-c/b].filter(t=>t>0&&t<1);const disc=b*b-4*a*c;if(disc<0)return [];return [(-b+Math.sqrt(disc))/(2*a),(-b-Math.sqrt(disc))/(2*a)].filter(t=>t>0&&t<1);}
function point(ps,t){return [0,1].map(k=>(1-t)**3*ps[0][k]+3*(1-t)**2*t*ps[1][k]+3*(1-t)*t*t*ps[2][k]+t**3*ps[3][k]);}
const box=ps=>[Math.min(...ps.map(p=>p[0])),Math.min(...ps.map(p=>p[1])),Math.max(...ps.map(p=>p[0])),Math.max(...ps.map(p=>p[1]))];
const unit=v=>{const l=Math.hypot(...v);if(l===0)throw Error('zero endpoint tangent');return v.map(x=>x/l);};
const sub=(a,b)=>a.map((x,i)=>x-b[i]),cross=(a,b)=>a[0]*b[1]-a[1]*b[0];
const reports=[];
for(const id of [10,75]){
 const f=fixtures[id],cs=f.subpaths[0].curves.map(c=>[0,2,4,6].map(i=>c.slice(i,i+2))),radius=f.width/2;
 const extrema=cs.flatMap((ps,curve)=>[0,1].flatMap(axis=>roots(ps,axis).map(t=>({curve,axis,t,point:point(ps,t)}))));
 const sourceBounds=box([...cs.flatMap(ps=>[ps[0],ps[3]]),...extrema.map(e=>e.point)]);
 // For these fixtures, coordinate support either occurs at an interior
 // source extremum plus radius or at an accepted miter. Record witnesses.
 const padded=[sourceBounds[0]-radius,sourceBounds[1]-radius,sourceBounds[2]+radius,sourceBounds[3]+radius];
 const miters=[];
 cs.forEach((ps,i)=>{const prev=cs[(i+cs.length-1)%cs.length],v=unit(sub(ps[1],ps[0])),w=unit(sub(prev[3],prev[2])),den=cross(v,w);if(Math.abs(den)<1e-12)return;for(const sign of [-1,1]){const a=[ps[0][0]+sign*radius*v[1],ps[0][1]-sign*radius*v[0]],b=[ps[0][0]+sign*radius*w[1],ps[0][1]-sign*radius*w[0]],t=cross(sub(b,a),w)/den;const p=[a[0]+t*v[0],a[1]+t*v[1]];if(Math.hypot(...sub(p,ps[0]))<=f.miterLimit*radius)miters.push({vertex:i,sign,point:p});}});
 const reference=box([[padded[0],padded[1]],[padded[2],padded[3]],...miters.map(m=>m.point)]);
 const paper=[f.paperActual[0],f.paperActual[1],f.paperActual[0]+f.paperActual[2],f.paperActual[1]+f.paperActual[3]];
 const path=s.subpath_as_path(unwrap(s.subpath_close(unwrap(s.subpath(toList(cs.map(ps=>new s.CubicBezier(...ps.map(p=>new s.Point(...p))))))))));
 const runs=[];
 for(const tolerance of [.01,.005,.002,.001,.0005,.0002,.0001,.00005,.00001,.000001]){
  const options=offset.default_options();options.fitting.tolerance=tolerance;
  const r=stroke.path_with(path,f.width,new offset.Miter(f.miterLimit),new offset.Butt(),options);
  if(!(r instanceof Ok)){runs.push({tolerance,status:'error',error:clean(r)});continue;}
  const out=r[0],b=unwrap(bounds.path_bounding_box(out)),actual=[b.min.x,b.min.y,b.max.x,b.max.y],points=[];let segments=0;
  for(const sp of s.path_subpaths(out).toArray())for(const seg of s.subpath_segments(sp).toArray()){
   segments++;const ps=seg instanceof s.CubicBezier?[seg.start,seg.control1,seg.control2,seg.end].map(p=>[p.x,p.y]):null;
   if(ps)for(const t of [0,1,...roots(ps,0),...roots(ps,1)])points.push(point(ps,t));
   else if(seg instanceof s.Line)points.push([seg.start.x,seg.start.y],[seg.end.x,seg.end.y]);
   else throw Error('Unsupported independent outline type: '+seg.constructor.name);
  }
  const independentOutlineBounds=box(points);
  runs.push({tolerance,status:'ok',segments,actual,edgeErrors:actual.map((x,i)=>x-reference[i]),libraryBoundsResidual:Math.max(...actual.map((v,i)=>Math.abs(v-independentOutlineBounds[i])))});
 }
 reports.push({fixtureIds:id===10?[10,42]:[75],referenceMethod:'Source derivative extrema with stroke-radius padding, plus accepted offset-tangent miters. All four supporting values are attained for these specific fixtures.',sourceBounds,extrema,miters,reference,paperEdgeResidual:Math.max(...paper.map((v,i)=>Math.abs(v-reference[i]))),runs});
}
fs.writeFileSync(new URL('./remaining-stroke-bounds-findings.json',import.meta.url),JSON.stringify(reports,null,2)+'\n');
console.log(JSON.stringify(reports.map(r=>({fixtureIds:r.fixtureIds,reference:r.reference,paperEdgeResidual:r.paperEdgeResidual,runs:r.runs.map(x=>x.status==='ok'?{tolerance:x.tolerance,segments:x.segments,maxEdgeError:Math.max(...x.edgeErrors.map(Math.abs)),libraryBoundsResidual:x.libraryBoundsResidual}:x)})),null,2));
