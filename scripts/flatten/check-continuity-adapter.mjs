import assert from 'node:assert/strict';
import fs from 'node:fs';
import {cap,makePolygonAdapter} from './continuity-adapter.mjs';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {polygonPath}=await import('./compare-arc-circle.mjs');
const calls=fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const ids=[3115,4278,4279,4280,4281,4282,4291,4292,4293,4294,4295,4296];
for(const id of ids){
 const c=calls[id-1],before=JSON.stringify(c);let rejected=0;
 for(const shape of [c.input,c.arguments[0],c.result]){
  try{polygonPath(shape);}catch(e){assert.equal(e.geometryError,'Discontinuous');rejected++;}
  for(const policy of ['end-to-next-start','start-to-previous-end']){
   const records=[];makePolygonAdapter(policy,records)(shape);
   assert(records.every(r=>r.gap>0&&r.gap<=cap));
  }
 }
 assert(rejected>0);assert.equal(JSON.stringify(c),before);
}
const bad=structuredClone(calls[4278-1].input);bad.faces[0][0].end.x+=1;
assert.throws(()=>makePolygonAdapter('end-to-next-start',[])(bad),e=>e.adapterGapExceedsCap===true);
console.log('12 captures unchanged; strict failures preserved; both adapter policies accepted bounded gaps; oversized gap rejected.');
