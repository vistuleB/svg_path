// Consumes the isolated-build report from investigate-boolean-errors.mjs.
// Usage: node scripts/paperjs/investigate-topology.mjs REPORT OUTPUT
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../..');import {pathToFileURL} from 'node:url';
const report=JSON.parse(fs.readFileSync(process.argv[2]));const base=report.scratch+'/svg_path/';const imp=p=>import(pathToFileURL(base+p));
const s=await imp('svg_path.mjs'),c=await imp('svg_path/csg.mjs'),a=await imp('svg_path/arrangement.mjs'),{toList,Ok}=await imp('gleam.mjs');
const data=JSON.parse(fs.readFileSync(path.join(root,'scripts/paperjs/booleans.json'))).fixtures;
function clean(v){if(v&&typeof v==='object'){if(v[Symbol.iterator]&&!Array.isArray(v))return [...v].map(clean);if(Array.isArray(v))return v.map(clean);return {type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))};}return v;}
function operand(g){return s.path_combine(toList(g.subpaths.map(p=>s.subpath_as_path(s.subpath_assert_close(s.subpath_assert(toList(p.curves.map(v=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(v[i],v[i+1])))))))))))}
const rows=[];
for(const r of report.results.filter(r=>r.result['0'].type==='InternalBoundaryTopologyError')){globalThis.auditTrace=[];const f=data.find(x=>x.id===r.id),l=operand(f.left),rr=operand(f.right);const b=c.csg_arrangement_build(toList([l,rr]),c.default_options())[0];const graph=b.graph;
 const row={id:r.id,validate:clean(a.validate_closed_boundaries(graph,1e-6,c.default_options().minimum_length)),classifications:[],cyclic:clean(graph.cyclic_orders)};
 const cls={unite:c.UnionOperation,intersect:c.IntersectionOperation,subtract:c.DifferenceOperation}[f.op];
 for(const tol of [1e-6,1e-7,1e-8,1e-9]){const res=c.classify_boolean_edges(graph.edges,l,rr,new s.Nonzero(),new cls(),tol,toList([]));let imbalance=[];
 if(res instanceof Ok){let counts={};for(const e of res[0]){counts[e.start_vertex]??=[0,0];counts[e.end_vertex]??=[0,0];counts[e.start_vertex][0]++;counts[e.end_vertex][1]++;}imbalance=Object.entries(counts).filter(([k,[i,j]])=>i!==j);}
 row.classifications.push({tolerance:tol,result:clean(res),imbalance});}
 rows.push(row);console.log(r.id,JSON.stringify(row.validate),row.classifications.map(x=>[x.tolerance,x.imbalance]));
 fs.writeFileSync(process.argv[3],JSON.stringify(rows,null,2));}
