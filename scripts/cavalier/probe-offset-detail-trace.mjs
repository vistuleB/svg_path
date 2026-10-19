import fs from 'node:fs';
import * as g from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path.mjs';
import * as off from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/offset.mjs';
import * as measure from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/measure.mjs';
import * as area from '/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/area.mjs';
import {toList} from '/tmp/cavalier-near-tangent-offset-trace/prelude.mjs';
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const c=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url))).find(c=>c.id===(process.env.AUDIT_CASE_ID??'CC01189'));
const finish=(p,s)=>p.closed?unwrap(g.subpath_close(s)):s;
const subs=(c.inputs??[c.input]).map(p=>finish(p,unwrap(g.subpath(toList(p.vertices.slice(0,p.closed?p.vertices.length:p.vertices.length-1).map((v,i)=>{
 const w=p.vertices[(i+1)%p.vertices.length],a=new g.Point(v[0],v[1]),b=new g.Point(w[0],w[1]),bulge=v[2];
 if(!bulge)return new g.Line(a,b);
 const r=Math.hypot(b.x-a.x,b.y-a.y)*(1+bulge*bulge)/(4*Math.abs(bulge));
 return new g.Arc(a,new g.Point(r,r),0,Math.abs(bulge)>1,bulge>0,b);
}))))));
const path=new g.Path(toList(subs)),rows=[];
for(const tolerance of (process.env.AUDIT_TOLERANCE?[Number(process.env.AUDIT_TOLERANCE)]:[.01,.001,.0001])){
 const base=off.default_options(),options=new off.Options(new off.FittingOptions(tolerance,base.fitting.samples,base.fitting.max_depth),base.stalled_offset_diameter,base.tangent_heal_angle_degrees,base.inner_join);
 const start=performance.now(),result=off.path_with(path,-c.offset,new off.Round(),new off.Butt(),options,off.default_single_offset_trimming());
 rows.push({normalization:subs.map(s=>[...g.subpath_segments(unwrap(off.normalize_source_subpath(s,options)))].map(s=>({type:s.constructor.name,...s}))),tolerance,milliseconds:performance.now()-start,result:result.isOk()?[...result[0].subpaths].map(s=>({area:area.signed_subpath(s),length:unwrap(measure.subpath_length(s)),segments:[...g.subpath_segments(s)].map(s=>({type:s.constructor.name,...s}))})):{error:result[0].constructor.name,...result[0]}});
}
console.log(JSON.stringify(rows,null,2));

console.error(JSON.stringify({errors:globalThis.auditErrors,arcs:globalThis.auditArcs,between:globalThis.auditBetween},null,2));
