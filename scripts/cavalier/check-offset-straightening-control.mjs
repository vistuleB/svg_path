import fs from 'node:fs';
const build='/tmp/cavalier-offset-straightening';
const dir=`${build}/svg_path_portable_tests`;
let passed=0,failed=[];
for(const file of fs.readdirSync(dir).filter(f=>f.endsWith('_test.mjs') && /offset|stroke|degeneracy|collapsed/.test(f)).sort()) {
 const m=await import(`${dir}/${file}`);
 for(const [name,fn] of Object.entries(m)) if(name.endsWith('_test') && typeof fn==='function') {
  try {await fn();passed++} catch(e){failed.push({file,name,error:String(e),detail:e});}
 }
}
console.log(JSON.stringify({passed,failed},null,2));
process.exitCode=failed.length?1:0;
