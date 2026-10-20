import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??new URL('../../test_portable/build/dev/javascript',import.meta.url).pathname;
const g=await import(`${build}/svg_path/svg_path.mjs`),o=await import(`${build}/svg_path/svg_path/offset.mjs`),d=await import(`${build}/svg_path/svg_path/degeneracy.mjs`),m=await import(`${build}/svg_path/svg_path/measure.mjs`),{toList}=await import(`${build}/prelude.mjs`);
const u=r=>{if(!r.isOk())throw r[0];return r[0]};
const desc=r=>r.isOk()?{segments:[...g.subpath_segments(r[0])],length:u(m.subpath_length(r[0]))}:{error:r[0].constructor.name,...r[0]};
const rows=[];
for(const xs of [[-1,0,.0002,.0001,.0003,1],[-2,0,1,.5,2,3],[-2,0,1,2,3]]){
 const source=u(g.subpath_polyline(toList(xs.map(x=>new g.Point(x,0)))));
 const normalized=desc(o.normalize_source_subpath(source,o.default_options()));
 const exactCleanup=desc(d.normalize_degenerate_segments(source,0));
 const raw=desc(o.subpath_untrimmed_with(source,-1,new o.Round(),o.default_options()));
 rows.push({xs,normalized,exactCleanup,raw});
}
console.log(JSON.stringify(rows,null,2));
