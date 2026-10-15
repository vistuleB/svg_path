// Run pinned upstream tests unmodified, then instrument the same tests to retain
// concrete inputs/results. The upstream source is restored even on failure.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const root = path.dirname(new URL(import.meta.url).pathname);
const source = process.env.FLO_SOURCE;
if (!source) throw Error('Set FLO_SOURCE to the extracted pinned source with npm ci completed.');
const relative = 'src/intersection/bezier-bezier-intersection/bezier-bezier-intersection.ts';
const setupRelative = '__tests__/helpers/jest.setup.ts';
const files = [relative, setupRelative];
const originals = files.map(file => fs.readFileSync(path.join(source,file),'utf8'));
const provenance = JSON.parse(fs.readFileSync(path.join(root,'provenance.json')));
for(let i=0;i<files.length;i++) {
  const expected = provenance.files.find(f => f.path===files[i]).sha256;
  if(createHash('sha256').update(originals[i]).digest('hex')!==expected) throw Error(`Source mismatch: ${files[i]}`);
}
const batch = process.env.FLO_BATCH ?? 'first-batch';
const specs = batch === 'intersections'
  ? JSON.parse(fs.readFileSync(path.join(root,'inventory.json'))).files.filter(f=>f.category==='intersection').map(f=>f.file)
  : ['__tests__/intersection/bezier-bezier-intersection/bezier-bezier-intersection-specific-cases.spec.ts'];
const capture = path.join(root,batch === 'first-batch' ? 'intersection-calls.jsonl' : `${batch}-calls.jsonl`);
const run = (name, instrumented) => {
  const result = spawnSync(process.execPath, ['node_modules/jest/bin/jest.js','--runInBand','--runTestsByPath',...specs,'--json',`--outputFile=${path.join(root,name+'.json')}`],
    {cwd:source,env:{...process.env,...(instrumented?{FLO_CAPTURE:capture}:{})},encoding:'utf8',timeout:600000});
  fs.writeFileSync(path.join(root,name+'.log'),(result.stdout??'')+(result.stderr??''));
  if(result.status!==0) throw Error(`${name} failed: ${result.error??result.stderr}`);
};
run(`upstream-${batch}`,false);
fs.writeFileSync(capture,'');
try {
  fs.writeFileSync(path.join(source,relative), originals[0].replace('function bezierBezierIntersection(', 'function auditedOriginalIntersection(')+`
function bezierBezierIntersection(ps1: number[][], ps2: number[][]): X[] {
  const result = auditedOriginalIntersection(ps1,ps2);
  const hook = (globalThis as any).__floCapture;
  if (hook) hook(ps1,ps2,result);
  return result;
}
`);
  fs.writeFileSync(path.join(source,setupRelative),originals[1]+`
import { appendFileSync } from 'node:fs';
(globalThis as any).__floCapture = (left, right, intersections) => {
  const state = expect.getState();
  appendFileSync(process.env.FLO_CAPTURE!, JSON.stringify({file:state.testPath?.slice(process.cwd().length+1),test:state.currentTestName,left,right,intersections})+'\\n');
};
`);
  run(`upstream-${batch}-instrumented`,true);
} finally {
  files.forEach((file,i)=>fs.writeFileSync(path.join(source,file),originals[i]));
}
console.log('Captured',fs.readFileSync(capture,'utf8').trim().split('\n').length,'calls; source restored.');
