import fs from 'node:fs';
const dir='/tmp/fl006-overlap-runtime/svg_path_portable_tests';
let passed=0;const failures=[];
for(const file of fs.readdirSync(dir).filter(n=>n.endsWith('_test.mjs'))){
 const m=await import(`${dir}/${file}`);
 for(const [name,f] of Object.entries(m))if(name.endsWith('_test')){try{await f();passed++;}catch(e){failures.push({file,name,error:String(e),stack:e.stack});}}
 console.log(file,passed,failures.length);
}
fs.writeFileSync(new URL('remaining-fl006-overlap-tests.json',import.meta.url),JSON.stringify({passed,failures},null,2)+'\n');
