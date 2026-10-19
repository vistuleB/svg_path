import fs from 'node:fs';
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from './probe/build/dev/javascript/svg_path/svg_path/offset.mjs';
import {toList} from './probe/build/dev/javascript/prelude.mjs';
import * as area from './probe/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as measure from './probe/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as bounds from './probe/build/dev/javascript/svg_path/svg_path/bounds.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const rows=[];
for(const id of ['CC01160','CC01189','CC01292','CC01296']){
 const c=cases.find(x=>x.id===id),vs=c.input.vertices;
 const ss=vs.slice(0,c.input.closed?vs.length:vs.length-1).map((v,i)=>{
  const w=vs[(i+1)%vs.length],p=new g.Point(v[0],v[1]),q=new g.Point(w[0],w[1]),b=v[2];
  if(!b)return new g.Line(p,q);
  const r=Math.hypot(q.x-p.x,q.y-p.y)*(1+b*b)/(4*Math.abs(b));
  return new g.Arc(p,new g.Point(r,r),0,Math.abs(b)>1,b>0,q);
 });
 let source=g.subpath(toList(ss));if(!source.isOk())throw source[0];source=source[0];
 if(c.input.closed){const r=g.subpath_close(source);if(!r.isOk())throw r[0];source=r[0];}
 const normalized=off.normalize_source_subpath(source,off.default_options());
 const r=off.subpath(source,-c.offset,new off.Round(),new off.Butt());
 rows.push({id,normalized:normalized.isOk()?{ok:true}:{ok:false,error:{type:normalized[0].constructor.name,...normalized[0]}},result:r.isOk()?{ok:true,subpaths:Array.from(r[0].subpaths).length,properties:Array.from(r[0].subpaths,s=>{const b=bounds.subpath_bounding_box(s)[0];return {area:c.input.closed?area.signed_subpath(s):0,length:measure.subpath_length(s)[0],bounds:[b.min.x,b.min.y,b.max.x,b.max.y]};}),expected:c.result}:{ok:false,error:{type:r[0].constructor.name,...r[0]}}});
}
console.log(JSON.stringify(rows,null,2));
