// Reuse the unchanged Boolean comparison policy against the isolated 107 experiment.
// Usage: node scripts/paperjs/screen-final-experiment.mjs REPORT /path/to/node_modules/paper OUTPUT [FIXTURE]
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
const report=JSON.parse(fs.readFileSync(process.argv[2]));
const root=path.resolve(import.meta.dirname,'../..');
const base=pathToFileURL(path.join(report.scratch,'svg_path')+'/').href;
let script=fs.readFileSync(path.join(import.meta.dirname,'probe-booleans.mjs'),'utf8');
script=script.replace("new URL('./booleans.json',import.meta.url)",`new URL(${JSON.stringify(pathToFileURL(path.join(import.meta.dirname,'booleans.json')).href)})`);
script=script.replaceAll('../../test_portable/build/dev/javascript/svg_path/',base);
const anchor=`const {toList,Ok}=await import('${base}gleam.mjs');`;
if(script.split(anchor).length!==2)throw Error('Missing comparison import anchor');
script=script.replace(anchor,anchor+`
 globalThis.auditTrace=[];globalThis.auditTick=()=>{};globalThis.auditPair=()=>{};globalThis.auditDiversity=()=>{};
 globalThis.auditOverlapCandidates=xs=>{const full=[...xs].find(x=>x[0]===0&&x[1]===1&&((x[2]===0&&x[3]===1)||(x[2]===1&&x[3]===0)));return full?toList([full]):xs;};
`);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'svg-final-screen-'));
const file=path.join(temp,'screen.mjs');fs.writeFileSync(file,script);
const result=spawnSync(process.execPath,[file,path.resolve(process.argv[3]),process.argv[5]??'107'],{cwd:root,env:{...process.env,PAPER_AUDIT_TIMEOUT_MS:'30000',PAPER_AUDIT_REPORT:path.resolve(process.argv[4])},stdio:'inherit'});
process.exitCode=result.status??1;
