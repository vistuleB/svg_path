// Diagnostic only: investigate issue #139 without changing production geometry.
import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as ov from '../../test_portable/build/dev/javascript/svg_path/svg_path/overlaps.mjs';
import * as arr from '../../test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
const call=JSON.parse(fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n')[4919]);
const segments=[...call.input.edges,...call.arguments[0].edges].map(e=>new g.Line(new g.Point(e.start.x,e.start.y),new g.Point(e.end.x,e.end.y)));
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const plain=x=>x.isOk()?{ok:true,hits:[...x[0]]}:{ok:false,error:x[0].constructor.name};
const rows=[];
for(const tolerance of [1e-6,1e-7,1e-8]){
 const graph=unwrap(arr.build_with(toList(segments),tolerance,1e-9,0));
 const left=segments[8],right=segments[20];
 const opts=Object.assign(ix.default_options(),{tolerance:tolerance/2});
 const pairs=[];
 for(const [a,b] of [[left,right],[right,left]]){
  const r=ix.segment_with(a,b,opts);pairs.push({left:a,right:b,result:plain(r)});
 }
 const edgePairs=[];
 for(const a of graph.graph.edges)for(const b of graph.graph.edges){
  if(a.id>=b.id)continue;
  const ai=[...graph.edge_images].find(x=>x.edge_id===a.id),bi=[...graph.edge_images].find(x=>x.edge_id===b.id);
  if([...ai.sources].some(x=>x.segment_index===8)&&[...bi.sources].some(x=>x.segment_index===20))
   edgePairs.push({left:a,right:b,result:plain(ix.segment_with(a.segment,b.segment,opts)),overlaps:plain(ov.segment_with(a.segment,b.segment,opts.tolerance))});
 }
 rows.push({tolerance,pairs,edgePairs});
}
fs.writeFileSync(new URL('remaining-fl004-crossings.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
for(const r of rows){console.log('tolerance',r.tolerance);for(const p of r.pairs)console.log('source pair',JSON.stringify(p.result));for(const p of r.edgePairs)console.log('edge pair',p.left.id,p.right.id,JSON.stringify(p.result));}
