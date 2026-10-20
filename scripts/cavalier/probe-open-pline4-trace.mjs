import fs from 'node:fs';
const build = process.env.AUDIT_JS_BUILD ?? new URL('../../test_portable/build/dev/javascript', import.meta.url).pathname;
const g = await import(`${build}/svg_path/svg_path.mjs`);
const off = await import(`${build}/svg_path/svg_path/offset.mjs`);
const measure = await import(`${build}/svg_path/svg_path/measure.mjs`);
const bounds = await import(`${build}/svg_path/svg_path/bounds.mjs`);
const area = await import(`${build}/svg_path/svg_path/area.mjs`);
const {toList} = await import(`${build}/prelude.mjs`);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
const c=JSON.parse(fs.readFileSync(process.env.AUDIT_CASE_FILE??new URL('./captured-cases.json',import.meta.url))).find(c=>c.id===(process.env.AUDIT_CASE_ID??'CC01189'));
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
 const mode=process.env.AUDIT_TRIMMING??'default';
 const trimming=new off.SingleOffsetTrimming(mode==='default'||mode==='offside-only',mode==='default'||mode==='no-offside'?new off.InBandTrimming():new off.NoTrimming());
 const start=performance.now(),result=off.path_with(path,-c.offset,new off.Round(),new off.Butt(),options,trimming);
 rows.push({mode,normalization:subs.map(s=>[...g.subpath_segments(unwrap(off.normalize_source_subpath(s,options)))].map(s=>({type:s.constructor.name,...s}))),tolerance,milliseconds:performance.now()-start,result:result.isOk()?[...result[0].subpaths].map(s=>({bounds:unwrap(bounds.subpath_bounding_box(s)),area:area.signed_subpath(s),length:unwrap(measure.subpath_length(s)),segments:[...g.subpath_segments(s)].map(s=>({type:s.constructor.name,...s}))})):{error:result[0].constructor.name,...result[0]}});
}
console.log(JSON.stringify(rows,null,2));

const plain=x=>x===null||typeof x!=='object'?x:(Symbol.iterator in x)?[...x].map(plain):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v)]))};
console.error(JSON.stringify(plain(globalThis.auditStages),null,2));
const containment = await import(`${build}/svg_path/svg_path/containment.mjs`);
const samples = globalThis.auditStages.filter(r=>r.edge).map(r=>{
 const p=unwrap(g.segment_point(r.edge.segment,.5)),d=unwrap(g.segment_derivative(r.edge.segment,.5)),n=Math.hypot(d.x,d.y);
 return {edge:r.edge.id,measured:r.measured[0],samples:[1e-3,1e-4,1e-5].map(e=>({epsilon:e,pair:[1,-1].map(sign=>{
 const q=new g.Point(p.x-sign*e*d.y/n,p.y+sign*e*d.x/n);
 return plain(containment.path_winding(q,globalThis.auditWindingPath));
 })}))};
});
fs.writeFileSync(new URL('./offset-post-reversal-CC01287-winding-samples.json',import.meta.url),JSON.stringify(samples,null,2)+'\n');
