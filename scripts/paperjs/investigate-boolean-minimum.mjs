// Option-sweep diagnostic; requires the isolated report from investigate-boolean-errors.mjs.
// Usage: node scripts/paperjs/investigate-boolean-minimum.mjs REPORT OUTPUT
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../..');import {pathToFileURL} from 'node:url';
const report=JSON.parse(fs.readFileSync(process.argv[2]));const base=report.scratch+'/svg_path/';const imp=p=>import(pathToFileURL(base+p));
const s=await imp('svg_path.mjs'),c=await imp('svg_path/csg.mjs'),a=await imp('svg_path/arrangement.mjs'),{toList,Ok}=await imp('gleam.mjs');
const data=JSON.parse(fs.readFileSync(path.join(root,'scripts/paperjs/booleans.json'))).fixtures;
function clean(v){if(v&&typeof v==='object'){if(v[Symbol.iterator]&&!Array.isArray(v))return [...v].map(clean);if(Array.isArray(v))return v.map(clean);return {type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))};}return v;}
function operand(g){return s.path_combine(toList(g.subpaths.map(p=>s.subpath_as_path(s.subpath_assert_close(s.subpath_assert(toList(p.curves.map(v=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(v[i],v[i+1])))))))))))}
const rows=[];
for(const r of report.results.filter(r=>[122,123].includes(r.id))){globalThis.auditTrace=[];const f=data.find(x=>x.id===r.id),l=operand(f.left),rr=operand(f.right);const b=c.csg_arrangement_build(toList([l,rr]),c.default_options())[0];const graph=b.graph;
 const row={id:r.id,variants:[]};
 for(const minimum of [1e-5,1e-7,1e-9]){
  const options=c.default_options();options.minimum_length=minimum;
  const built=c.csg_arrangement_build(toList([l,rr]),options);if(!(built instanceof Ok)){row.variants.push({minimum,buildError:clean(built)});console.log(r.id,minimum,JSON.stringify(clean(built)));continue;}const graph=built[0].graph;
  const cls={unite:c.UnionOperation,intersect:c.IntersectionOperation}[f.op];
  let v={minimum,validation:clean(a.validate_closed_boundaries(graph,1e-6,minimum)),vertices:clean(graph.vertices),edges:clean(graph.edges),images:clean(built[0]),variants:[]};
  for(const tol of [1e-6,1e-7]){
   const res=c.classify_boolean_edges(graph.edges,l,rr,new s.Nonzero(),new cls(),tol,toList([]));let counts={};
   for(const e of res[0]){counts[e.start_vertex]??=[0,0];counts[e.end_vertex]??=[0,0];counts[e.start_vertex][0]++;counts[e.end_vertex][1]++;}
   v.variants.push({tol,imbalance:Object.entries(counts).filter(([k,[i,j]])=>i!==j)});
  }
  row.variants.push(v);console.log(r.id,minimum,JSON.stringify(v.validation),JSON.stringify(v.variants));
 }
 rows.push(row);fs.writeFileSync(process.argv[3],JSON.stringify(rows,null,2));}
