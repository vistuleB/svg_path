import fs from 'node:fs';
import { construct } from '../../test_paperjs/build/dev/javascript/svg_path_paper_audit/paper_bulk_checks.mjs';
const results=[];
for(const count of [100,1000,5000,10000,100000])for(const distinct of [false,true]){
 try { const result=construct(count,distinct);results.push({count,distinct,result:result.isOk()?'Ok':'Error',edges:result.isOk()?result[0]:null}); }
 catch(error){results.push({count,distinct,error:error.name,message:error.message,stack:error.stack.split('\n').slice(0,9)});}
}
fs.writeFileSync(new URL('./bulk-construction-findings.json',import.meta.url),JSON.stringify({node:process.version,results},null,2)+'\n');
console.log(results.map(({count,distinct,result,error})=>({count,distinct,result,error})));
