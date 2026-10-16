import fs from 'node:fs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import {makePolygonAdapter,cap} from './continuity-adapter.mjs';
process.env.FLATTEN_LIBRARY_ONLY='1';
const {compare}=await import('./compare-arc-circle.mjs');
const calls=fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const rows=[];
for(const ids of [[4278,4279,4280,4281,4282],[4291,4292,4293,4294,4295,4296]])for(const policy of ['end-to-next-start','start-to-previous-end']){
 let previous=null;const steps=[],adjustments=[];
 for(const id of ids){
  const adapter=makePolygonAdapter(policy,adjustments);let conversion=0,output;
  const adaptPolygon=shape=>conversion++===0&&previous?previous:adapter(shape);
  const result=compare(calls[id-1],{adaptPolygon,observeBoolean:(actual,expected)=>{output=actual;}});
  steps.push({id,result,subpaths:output?[...output.subpaths].map(s=>({segments:[...s.segments].length,signedArea:area.signed_subpath(s)})):null});
  if(!output)break;previous=output;
 }
 rows.push({ids,policy,cap,adjustments,steps});
}
fs.writeFileSync(new URL('remaining-continuity-chains.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
for(const r of rows)console.log(r.ids[0],r.policy,JSON.stringify(r.steps));
