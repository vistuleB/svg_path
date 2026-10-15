// Capture actual upstream calls in a disposable extraction, restoring all sources.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const root=path.dirname(new URL(import.meta.url).pathname);
const source=process.env.FLO_SOURCE;
if(!source) throw Error('Set FLO_SOURCE to the pinned disposable extraction');
const targets=[["isBezierPieceZeroLength", "bezier-piece/is-bezier-piece-zero-length"], ["getControlPointBox", "global-properties/bounds/get-control-point-box"], ["getXBoundsTight", "global-properties/bounds/get-x-bounds-tight"], ["getYBoundsTight", "global-properties/bounds/get-y-bounds-tight"], ["controlPointLinesLength", "global-properties/length/control-point-lines-length"], ["circleBezierIntersection", "intersection/circle-bezier-intersection/circle-bezier-intersection"], ["closestPointsBetweenBeziers", "simultaneous-properties/closest-distance-between-beziers/closest-points-between-beziers"], ["reverse", "transformation/reverse"], ["toCubic", "transformation/degree-or-type/to-cubic"], ["lineToCubic", "transformation/degree-or-type/line-to-cubic"], ["quadraticToCubic", "transformation/degree-or-type/quadratic-to-cubic"], ["getHodograph", "transformation/get-hodograph"], ["splitByLength", "transformation/split/split-by-length"], ["quadraticToPolyline", "fit/quadratic-to-polyline"], ["getDistanceToLineFunction", "utils/get-distance-to-line-function"]];
targets.push(['getEndpointIntersections','intersection/get-endpoint-intersections/get-endpoint-intersections'],['splitByDeviationFromStraightLine','transformation/split/split-by-deviation-from-straight-line']);
const inventory=JSON.parse(fs.readFileSync(path.join(root,'inventory.json')));
// Capture only tests that directly import each target, rather than all helper calls.
const scopes=Object.fromEntries(targets.map(([name,module])=>[name,inventory.files.filter(f=>{
 const s=fs.readFileSync(path.join(root,'upstream',f.file),'utf8');
 return s.split('\n').some(line=>line.includes('import')&&line.includes(name)&&line.includes(path.basename(module)+'.js'));
}).map(f=>f.file)]));
const specs=JSON.parse(fs.readFileSync(path.join(root,'remaining-files.json')));
for(const name of Object.keys(scopes))scopes[name]=scopes[name].filter(f=>specs.includes(f));
fs.writeFileSync(path.join(root,'remaining-scopes.json'),JSON.stringify(scopes,null,2)+'\n');
const setup='__tests__/helpers/jest.setup.ts';
const files=[...targets.map(([,p])=>'src/'+p+'.ts'),setup];
const originals=files.map(f=>fs.readFileSync(path.join(source,f),'utf8'));
const provenance=JSON.parse(fs.readFileSync(path.join(root,'provenance.json')));
files.forEach((f,i)=>{if(createHash('sha256').update(originals[i]).digest('hex')!==provenance.files.find(x=>x.path===f).sha256)throw Error('Source mismatch '+f);});
const capture=path.join(root,'remaining-calls.jsonl');
function run(name,instrumented){
 const r=spawnSync(process.execPath,['node_modules/jest/bin/jest.js','--runInBand','--runTestsByPath',...specs,'--json','--outputFile='+path.join(root,name+'.json')],{cwd:source,env:{...process.env,FLO_CAPTURE:instrumented?capture:''},encoding:'utf8',timeout:600000});
 fs.writeFileSync(path.join(root,name+'.log'),(r.stdout??'')+(r.stderr??''));
 if(r.status!==0)throw Error(name+' failed; see log '+r.error);
}
run('upstream-remaining',false);
fs.writeFileSync(capture,'');
try{
 targets.forEach(([name],i)=>{
  const renamed=originals[i].replaceAll('function '+name+'(', 'function auditedOriginal_'+name+'(');
  if(renamed===originals[i])throw Error('Declaration not found '+name);
  fs.writeFileSync(path.join(source,files[i]),renamed+`
function ${name}(...args: any[]): any {
 const hook = (globalThis as any).__floNumericCapture;
 let result;
 try { result = (auditedOriginal_${name} as any)(...args); }
 catch(e) { if(hook)hook('${name}',args,undefined,String(e)); throw e; }
 if(typeof result === 'function')return (...tail: any[])=>{
   const value=result(...tail); if(hook)hook('${name}',[...args,...tail],value); return value;
 };
 if(hook)hook('${name}',args,result);
 return result;
}
`);
 });
 fs.writeFileSync(path.join(source,setup),originals.at(-1)+`
import {appendFileSync} from 'node:fs';
const auditScopes = ${JSON.stringify(scopes)};
(globalThis as any).__floNumericCapture=(operation,args,result,error)=>{
 const state=expect.getState(); const file=state.testPath?.slice(process.cwd().length+1);
 if(!auditScopes[operation]?.includes(file))return;
 const caller = new Error().stack?.split('\\n')[3] ?? '';
 if(!caller.includes(state.testPath+':'))return;
 appendFileSync(process.env.FLO_CAPTURE!,JSON.stringify({file,test:state.currentTestName,operation,args,result,error},(_,v)=>typeof v==='number'&&!Number.isFinite(v)?String(v):v)+'\\n');
};
`);
 run('upstream-remaining-instrumented',true);
}finally{files.forEach((f,i)=>fs.writeFileSync(path.join(source,f),originals[i]));}
console.log(specs.length+' files; '+fs.readFileSync(capture,'utf8').trim().split('\n').length+' captured calls; source restored');
