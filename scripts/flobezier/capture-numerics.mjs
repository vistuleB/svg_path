// Capture actual upstream calls in a disposable extraction, restoring all sources.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const root=path.dirname(new URL(import.meta.url).pathname);
const source=process.env.FLO_SOURCE;
if(!source) throw Error('Set FLO_SOURCE to the pinned disposable extraction');
const targets=[
 ['area','global-properties/area'],
 ['evaluate1stDerivative','local-properties-at-t/evaluate-1st-derivative/double/evaluate-1st-derivative'],
 ['evaluate2ndDerivative','local-properties-at-t/evaluate-2nd-derivative/double/evaluate-2nd-derivative'],
 ['length','global-properties/length/length'],
 ['getTAtLength','local-properties-to-t/get-t-at-length'],
 ['getBoundingBox','global-properties/bounds/get-bounding-box'],
 ['getBoundingBoxTight','global-properties/bounds/get-bounding-box-tight'],
 ['getBounds','global-properties/bounds/get-bounds'],
 ['closestPointOnBezier','simultaneous-properties/closest-and-furthest-point-on-bezier/closest-point-on-bezier'],
 ['closestPointOnBezierCertified','simultaneous-properties/closest-and-furthest-point-on-bezier/closest-point-on-bezier-certified'],
 ['bezierSelfIntersection','intersection/self-intersection/bezier-self-intersection'],
 ['getInflections','global-properties/get-inflections'],
 ['fromTo','transformation/split/from-to'],
 ['evalDeCasteljau','local-properties-at-t/evaluate/double/eval-de-casteljau'],
 ['curvature','local-properties-at-t/curvature/curvature'],
];
for (const name of ['flipAbout','flipHorizontally','flipVertically','rotate90About','rotate90','rotateAbout','rotateNeg90About','rotateNeg90','rotate','scale','transform','translate']) {
 const file=name.replace(/[A-Z]/g,c=>'-'+c.toLowerCase()).replace('rotate90','rotate-90').replace('neg90','neg-90');
 targets.push([name,'transformation/affine/'+file]);
}
const inventory=JSON.parse(fs.readFileSync(path.join(root,'inventory.json')));
// Capture only tests that directly import each target, rather than all helper calls.
const scopes=Object.fromEntries(targets.map(([name,module])=>[name,inventory.files.filter(f=>{
 const s=fs.readFileSync(path.join(root,'upstream',f.file),'utf8');
 return s.split('\n').some(line=>line.includes('import')&&line.includes(name)&&line.includes(path.basename(module)+'.js'));
}).map(f=>f.file)]));
scopes.evaluate1stDerivative.push(...inventory.files.filter(f=>fs.readFileSync(path.join(root,'upstream',f.file),'utf8').split('\n').some(line=>line.includes('import')&&line.includes('/tangent/double/tangent.js'))).map(f=>f.file));
for(const name of ['evaluate1stDerivative','evaluate2ndDerivative']) scopes[name]=scopes[name].filter(f=>f.includes('/local-properties-at-t/'));
scopes.evalDeCasteljau=scopes.evalDeCasteljau.filter(f=>f.includes('/evaluate/double/evaluate.spec.ts'));
const specs=[...new Set(Object.values(scopes).flat())];
fs.writeFileSync(path.join(root,'numeric-scopes.json'),JSON.stringify(scopes,null,2)+'\n');
const setup='__tests__/helpers/jest.setup.ts';
const files=[...targets.map(([,p])=>'src/'+p+'.ts'),setup];
const originals=files.map(f=>fs.readFileSync(path.join(source,f),'utf8'));
const provenance=JSON.parse(fs.readFileSync(path.join(root,'provenance.json')));
files.forEach((f,i)=>{if(createHash('sha256').update(originals[i]).digest('hex')!==provenance.files.find(x=>x.path===f).sha256)throw Error('Source mismatch '+f);});
const capture=path.join(root,'numeric-calls.jsonl');
function run(name,instrumented){
 const r=spawnSync(process.execPath,['node_modules/jest/bin/jest.js','--runInBand','--runTestsByPath',...specs,'--json','--outputFile='+path.join(root,name+'.json')],{cwd:source,env:{...process.env,FLO_CAPTURE:instrumented?capture:''},encoding:'utf8',timeout:600000});
 fs.writeFileSync(path.join(root,name+'.log'),(r.stdout??'')+(r.stderr??''));
 if(r.status!==0)throw Error(name+' failed; see log '+r.error);
}
run('upstream-numerics',false);
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
 run('upstream-numerics-instrumented',true);
}finally{files.forEach((f,i)=>fs.writeFileSync(path.join(source,f),originals[i]));}
console.log(specs.length+' files; '+fs.readFileSync(capture,'utf8').trim().split('\n').length+' captured calls; source restored');
