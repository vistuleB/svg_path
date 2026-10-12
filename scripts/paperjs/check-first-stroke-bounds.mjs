// Independent extrema reference + option sweep for duplicated fixtures 9 / 41.
import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
import * as stroke from '../../test_portable/build/dev/javascript/svg_path/svg_path/stroke.mjs';
import * as offset from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import {Ok,toList} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const f=JSON.parse(fs.readFileSync(new URL('./bounds.json',import.meta.url))).fixtures[9];
const controls=[0,2,4,6].map(i=>new s.Point(...f.subpaths[0].curves[0].slice(i,i+2)));
const unwrap=r=>{if(!(r instanceof Ok))throw r;return r[0];};
const clean=v=>v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;
const curve=new s.CubicBezier(...controls);
const path=s.subpath_as_path(unwrap(s.subpath_close(unwrap(s.subpath(toList([curve]))))));
// Evaluate polynomial derivatives directly, independently of Gleam and Paper.
function roots(k,points=controls){const [p,q,r,t]=points.map(p=>p[k]);const a=-p+3*q-3*r+t,b=2*(p-2*q+r),c=q-p;return [(-b+Math.sqrt(b*b-4*a*c))/(2*a),(-b-Math.sqrt(b*b-4*a*c))/(2*a)].filter(t=>t>0&&t<1);}
function point(t,points=controls){return ['x','y'].map(k=>(1-t)**3*points[0][k]+3*(1-t)**2*t*points[1][k]+3*(1-t)*t*t*points[2][k]+t**3*points[3][k]);}
const extrema={x:roots('x').map(t=>({t,point:point(t)})),y:roots('y').map(t=>({t,point:point(t)}))};
// Offset tangent lines at the closure determine the outer miter. Both outward
// normal lines meet to the left of the source corner for this clockwise loop.
const unit=v=>{const l=Math.hypot(...v);return v.map(x=>x/l);};
const v=unit([controls[1].x-controls[0].x,controls[1].y-controls[0].y]);
const w=unit([controls[0].x-controls[2].x,controls[0].y-controls[2].y]);
const n=[v[1],-v[0]],m=[w[1],-w[0]];
const a=[controls[0].x+n[0]/2,controls[0].y+n[1]/2],b=[controls[0].x+m[0]/2,controls[0].y+m[1]/2];
const cross=(a,b)=>a[0]*b[1]-a[1]*b[0];const t=cross([b[0]-a[0],b[1]-a[1]],w)/cross(v,w);
const miter=[a[0]+t*v[0],a[1]+t*v[1]];
const reference=[miter[0],Math.min(...extrema.y.map(x=>x.point[1]))-.5,Math.max(...extrema.x.map(x=>x.point[0]))+.5,Math.max(...extrema.y.map(x=>x.point[1]))+.5];
const runs=[];
for(const tolerance of [.01,.005,.002,.001,.0005,.0002,.0001,.000001]){
 const options=offset.default_options();options.fitting.tolerance=tolerance;
 const result=stroke.path_with(path,1,new offset.Miter(10),new offset.Butt(),options);
 if(!(result instanceof Ok)){runs.push({tolerance,status:'error',error:clean(result)});continue;}
 const out=result[0],box=unwrap(bounds.path_bounding_box(out)),actual=[box.min.x,box.min.y,box.max.x,box.max.y];
 const points=[];
 for(const sub of s.path_subpaths(out).toArray())for(const segment of s.subpath_segments(sub).toArray()){
  if(segment instanceof s.Line){points.push([segment.start.x,segment.start.y],[segment.end.x,segment.end.y]);}
  else if(segment instanceof s.CubicBezier){const ps=[segment.start,segment.control1,segment.control2,segment.end];for(const t of [0,1,...roots('x',ps),...roots('y',ps)])points.push(point(t,ps));}
  else throw Error('Independent bounds checker needs segment type '+segment.constructor.name);
 }
 const independentOutlineBounds=[Math.min(...points.map(p=>p[0])),Math.min(...points.map(p=>p[1])),Math.max(...points.map(p=>p[0])),Math.max(...points.map(p=>p[1]))];
 runs.push({tolerance,status:'ok',independentOutlineBounds,libraryBoundsResidual:Math.max(...actual.map((v,i)=>Math.abs(v-independentOutlineBounds[i]))),segments:s.path_subpaths(out).toArray().reduce((n,p)=>n+s.subpath_segments(p).toArray().length,0),actual,edgeErrors:actual.map((x,i)=>x-reference[i])});
}
fs.writeFileSync(new URL('./first-stroke-bounds-findings.json',import.meta.url),JSON.stringify({fixtureIds:[9,41],referenceMethod:'Cubic derivative extrema, radius 0.5 normal offsets, and intersection of the two offset tangent lines at closure. Reference lists minX,minY,maxX,maxY.',extrema,miter,reference,runs},null,2)+'\n');
console.log(JSON.stringify({reference,runs},null,2));
