// Reconstruct missing source intervals, then replay all affected public operations.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as a from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
import {path,unwrap} from './triage-geometry.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const selected=cases.filter(c=>c.kind==='boolean'&&c.test==='test_specific::parametric_from_point_debug_assert_reported2');
const encode=x=>x===null||typeof x!=='object'?x:Array.isArray(x)?x.map(encode):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))};
function portion(s,lo,hi){if(hi<1)s=unwrap(g.segment_split(s,hi))[0];if(lo>0)s=unwrap(g.segment_split(s,lo/hi))[1];return s;}
const operations={Or:csg.union_path_with,And:csg.intersection_path_with,Not:csg.difference_path_with,Xor:csg.symmetric_difference_path_with};
const rows=[];
for(const c of selected){
 const left=path(c.input),right=path(c.other),segments=[...left.subpaths,...right.subpaths].flatMap(s=>[...s.segments]);
 const row={id:c.id,operation:c.operation,runs:[]};
 for(const minimum of [1e-5,1e-6,1e-7,1e-8]){
  const options=new csg.Options(1e-6,minimum),built=a.build_with(toList(segments),options.tolerance,minimum,0),run={minimum};
  if(!built.isOk()){run.buildError=encode(built[0]);row.runs.push(run);continue;}
  run.gaps=[];
  for(const image of built[0].segment_images){
   let end=0;
   const addGap=(lo,hi)=>{if(hi<=lo)return;const s=portion(segments[image.segment_index],lo,hi);run.gaps.push({segment:image.segment_index,lo,hi,lengthUpperBound:unwrap(measure.segment_length_upper_bound(s)),geometry:encode(s)});};
   for(const edge of [...image.edges].sort((x,y)=>x.ta-y.ta)){addGap(end,edge.ta);end=Math.max(end,edge.tb);}addGap(end,1);
  }
  const result=operations[c.operation](left,right,new g.Nonzero(),options);
  run.result=result.isOk()?{subpaths:[...result[0].subpaths].length}:encode(result[0]);
  row.runs.push(run);
 }
 rows.push(row);
}
console.log(JSON.stringify(rows,null,2));
