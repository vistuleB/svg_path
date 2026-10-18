import fs from 'node:fs';
import * as arrangement from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import * as csg from '../../test_portable/build/dev/javascript/svg_path/svg_path/csg.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
import {path,unwrap} from './triage-geometry.mjs';
const cases=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const ids=JSON.parse(fs.readFileSync(new URL('./discrepancy-queue.json',import.meta.url))).filter(c=>c.kind==='boolean'&&c.status==='error').map(c=>c.id);
const encode=x=>x===null||typeof x!=='object'?x:Array.isArray(x)?x.map(encode):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]))};
const rows=[];
for(const c of cases.filter(c=>ids.includes(c.id))){
 const a=Array.from(path(c.input).subpaths).flatMap(s=>Array.from(s.segments)),b=Array.from(path(c.other).subpaths).flatMap(s=>Array.from(s.segments));
 const options=csg.default_options(),row={id:c.id,operation:c.operation,builds:[]};
 for(const minLength of [options.minimum_length,1e-8]){
  const result=arrangement.build_with(toList([...a,...b]),options.tolerance,minLength,0);
  if(!result.isOk()){row.builds.push({minimum_length:minLength,error:encode(result[0])});continue;}
  const built=result[0],edges=new Map(Array.from(built.graph.edges).map(e=>[e.id,e]));
  const flows=[0,1].map(operand=>{
   const f=new Map();
   for(const image of built.edge_images){const e=edges.get(image.edge_id);let weight=0;for(const src of image.sources)if((src.segment_index<a.length)===(operand===0))weight+=src.reversed?-1:1;f.set(e.start_vertex,(f.get(e.start_vertex)??0)-weight);f.set(e.end_vertex,(f.get(e.end_vertex)??0)+weight);}
   return [...f].filter(([id,v])=>v!==0);
  });
  row.builds.push({minimum_length:minLength,edges:edges.size,operand_nonzero_flows:flows});
 }
 rows.push(row);
}
console.log(JSON.stringify(rows,null,2));
