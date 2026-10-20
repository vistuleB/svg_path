import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??new URL('../../test_portable/build/dev/javascript',import.meta.url).pathname;
const g=await import(`${build}/svg_path/svg_path.mjs`), off=await import(`${build}/svg_path/svg_path/offset.mjs`),area=await import(`${build}/svg_path/svg_path/area.mjs`),ser=await import(`${build}/svg_path/svg_path/serialize.mjs`),{toList}=await import(`${build}/prelude.mjs`);
const p=(x,y)=>new g.Point(x,y),vs=[p(-1,-1),p(1,-1),p(1,1),p(-1,1)];
const source=g.subpath_close(g.subpath(toList(vs.map((a,i)=>new g.Line(a,vs[(i+1)%4]))))[0])[0];
const rows=[];
for(const distance of [.5,1,1.25,1.5,2,2.5]) {
 globalThis.auditDistance=distance;
 const r=off.subpath(source,-distance,new off.Round(),new off.Butt());
 rows.push({distance,result:r.isOk()?{ok:true,subpaths:Array.from(r[0].subpaths,s=>({area:area.signed_subpath(s),svg:ser.subpath(s),segments:Array.from(g.subpath_segments(s))}))}:{ok:false,error:r[0]}});
}
console.log(JSON.stringify(rows,null,2));
