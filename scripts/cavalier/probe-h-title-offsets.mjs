import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??new URL('../../examples/public_api_smoke/build/dev/javascript',import.meta.url).pathname;
const p=await import(`${build}/svg_path/svg_path/parse.mjs`),o=await import(`${build}/svg_path/svg_path/offset.mjs`);
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]};
let path=unwrap(p.path(fs.readFileSync(new URL('../../examples/debug/package_title.svg',import.meta.url),'utf8').split(' d="')[1].split('"')[0]));
for(let level=1;level<=9;level++){
 const start=performance.now();const result=o.path_with(path,1.04,new o.Miter(o.default_miter_limit),new o.Butt(),o.default_options(),o.default_single_offset_trimming());
 console.log(JSON.stringify({level,milliseconds:performance.now()-start,ok:result.isOk(),error:result.isOk()?null:result[0]}));
 if(!result.isOk()){process.exitCode=1;break}path=result[0];
}
