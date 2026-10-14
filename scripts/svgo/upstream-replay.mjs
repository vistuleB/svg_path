// Baseline verification only: running these is NOT an audit of our library.
import fs from 'node:fs';
import { optimize } from 'svgo';
const root=new URL('./',import.meta.url);
const fixtures=JSON.parse(fs.readFileSync(new URL('extra-fixtures.json',root)));
const rows=[];
for(const f of fixtures){
 let text=f.original;const passes=[];
 try {
  for(let n=0;n<(['convertTransform','addAttributesToSVGElement'].includes(f.plugin)?1:2);n++){
   text=optimize(text,{path:`test/plugins/${f.file}`,plugins:[{name:f.plugin,params:f.params}],js2svg:{pretty:true}}).data;
   passes.push(text.trim()===f.expected.trim());
  }
  rows.push({file:f.file,passes});
 } catch(error){rows.push({file:f.file,error:String(error)});}
}
fs.writeFileSync(new URL('upstream-replay.json',root),JSON.stringify(rows,null,2)+'\n');
const failed=rows.filter(r=>r.error||r.passes.some(x=>!x));
console.log(`${rows.length} baseline fixtures; ${failed.length} mismatches/errors`);console.log(failed);
if(failed.length)process.exitCode=1;
