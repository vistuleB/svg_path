import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??'/tmp/cc01301-adaptive-arcs',dir=`${build}/svg_path_portable_tests`;
let passed=0,failed=[],modules=[];
for(const file of fs.readdirSync(dir).filter(f=>f.endsWith('_test.mjs') && /arrangement|offset|stroke|csg|arc_|semicircle/.test(f)).sort()) {
 modules.push(file);const m=await import(`${dir}/${file}`);
 for(const [name,fn] of Object.entries(m)) if(name.endsWith('_test') && typeof fn==='function') {
  try {await fn();passed++} catch(e){failed.push({file,name,error:String(e),detail:e});}
 }
}
console.log(JSON.stringify({build,modules,passed,failed},null,2));process.exitCode=failed.length?1:0;
