// Historical instrumentation for the classifier at 911ba22. The face-winding
// replacement removes the private sampling hooks patched by this script.
// Read-only production investigation: private exports live in a temporary copy.
// Build: (cd test_paperjs && gleam build --target javascript)
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const repo=path.resolve(import.meta.dirname,'../..');
const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'svg-boundary-classification-'));
fs.cpSync(path.join(repo,'test_paperjs/build/dev/javascript'),scratch,{recursive:true});
fs.appendFileSync(path.join(scratch,'svg_path/svg_path/csg.mjs'),'\nexport {csg_arrangement_build, classify_boolean_edges, UnionOperation, IntersectionOperation, DifferenceOperation, csg_path_segments, BoundaryEdge, pair_boundary_sectors, trace_boundary_edges, vertex_points};\n');
const compiledCsg=path.join(scratch,'svg_path/svg_path/csg.mjs');
const source=fs.readFileSync(compiledCsg,'utf8');
if(source.split('tolerance * 16.0').length!==3)throw Error('Sampling-distance anchor changed');
fs.writeFileSync(compiledCsg,source.replaceAll('tolerance * 16.0','(globalThis.csgSideDistance ?? tolerance * 16.0)'));
const paper=createRequire(import.meta.url)('/tmp/svg-path-paper-audit/node_modules/paper');
paper.setup(new paper.Size(1000,1000));
function paperOperand(g){return new paper.CompoundPath({children:g.subpaths.map(p=>new paper.Path({insert:false,closed:true,segments:p.curves.map((v,i)=>{const prev=p.curves[(i+p.curves.length-1)%p.curves.length];return new paper.Segment([v[0],v[1]],[prev[4]-v[0],prev[5]-v[1]],[v[2]-v[0],v[3]-v[1]]);})})),insert:false});}
const imp=p=>import(pathToFileURL(path.join(scratch,'svg_path',p)));
const s=await imp('svg_path.mjs'), c=await imp('svg_path/csg.mjs'), a=await imp('svg_path/arrangement.mjs');
const w=await imp('svg_path/internal/winding_field.mjs'),q=await imp('svg_path/internal/query.mjs'),ct=await imp('svg_path/containment.mjs');
const {toList,Ok}=await imp('gleam.mjs');
const serialize=await imp('svg_path/serialize.mjs');
const clean=v=>v&&typeof v==='object'?(v[Symbol.iterator]&&!Array.isArray(v)?[...v].map(clean):Array.isArray(v)?v.map(clean):{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}):v;
function operand(g){return s.path_combine(toList(g.subpaths.map(p=>s.subpath_as_path(s.subpath_assert_close(s.subpath_assert(toList(p.curves.map(v=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(v[i],v[i+1])))))))))))}
function balance(edges){const counts=new Map();for(const e of edges){for(const [id,k] of [[e.start_vertex,0],[e.end_vertex,1]]){if(!counts.has(id))counts.set(id,[0,0]);counts.get(id)[k]++;}}return [...counts].filter(([id,[a,b]])=>a!==b);}
function dualClassification(built,left,operation){
 const graph=built[0].graph;let diagnostic;
 const dual=a.dual(graph);
 diagnostic={result:clean(dual)};
 if(dual instanceof Ok){
  const leftCount=[...c.csg_path_segments(toList([left]),toList([]))].length;
  const windings=[0,1].map(operand=>a.face_windings(dual[0],toList([...built[0].edge_images].map(image=>new a.EdgeWindingChange(image.edge_id,[...image.sources].filter(source=>(source.segment_index<leftCount?0:1)===operand).reduce((sum,source)=>sum+(source.reversed?-1:1),0))))));
  diagnostic.windings=windings.map(clean);
  if(windings.every(x=>x instanceof Ok)){
   const maps=windings.map(x=>new Map([...x[0]].map(w=>[w.face_id,w.value])));
   const edgeFaces=new Map([...dual[0].edge_faces].map(x=>[x.edge_id,x]));
   const boundary=[];diagnostic.classified=[];
   for(const e of graph.edges){
    const faces=edgeFaces.get(e.id),levels=maps.map(m=>[m.get(faces.left_face),m.get(faces.right_face)]);
    const combine=(x,y)=>operation==='unite'?(x!==0||y!==0):(x!==0&&y!==0);
    const l=combine(levels[0][0],levels[1][0]),r=combine(levels[0][1],levels[1][1]);
    diagnostic.classified.push({id:e.id,a:levels[0],b:levels[1],orientation:l===r?0:l?-1:1});
    if(l!==r)boundary.push(new c.BoundaryEdge(e.id,0,l?s.segment_reverse(e.segment):e.segment,l?e.end_vertex:e.start_vertex,l?e.start_vertex:e.end_vertex));
   }
   diagnostic.imbalance=balance(boundary);
   const links=c.pair_boundary_sectors(graph,toList(boundary));
   diagnostic.links=clean(links);
   if(links instanceof Ok){const traced=c.trace_boundary_edges(toList(boundary),links[0],c.vertex_points(graph),toList([]));diagnostic.traced=clean(traced);if(traced instanceof Ok){const opts=serialize.default_options();opts.right_decimals=new serialize.System();opts.use_s_t=false;opts.use_h_v=false;diagnostic.outputPathData=serialize.path_with(new s.Path(traced[0]),opts);}}
  }
 }
 return diagnostic;
}
const fixtures=JSON.parse(fs.readFileSync(path.join(repo,'scripts/paperjs/booleans.json'))).fixtures;
const rows=[];
for(const id of [79,113]){
 const f=fixtures.find(x=>x.id===id),left=operand(f.left),right=operand(f.right);
 const result=c[f.op==='unite'?'union_path':'intersection_path'](left,right,new s.Nonzero());
 const built=c.csg_arrangement_build(toList([left,right]),c.default_options());
 if(!(built instanceof Ok))throw Error('Cannot construct '+id);
 const graph=built[0].graph;
 const paperPaths=[paperOperand(f.left),paperOperand(f.right)];
 const row={id,operation:f.op,result:clean(result),graph:clean(graph),valid:clean(a.validate_closed_boundaries(graph,1e-6,c.default_options().minimum_length)),sweeps:[]};
 for(const tolerance of [1e-6,1e-7,1e-8,1e-9])for(const distance of [16e-6,16e-7,16e-8,16e-9]){
  const opts=ct.default_containment_options();opts.tolerance=tolerance;
  const classified=[],selected=[];
  for(const e of graph.edges){
   const al=w.segment_side_nonzero_levels(e.segment,left,distance,opts),bl=w.segment_side_nonzero_levels(e.segment,right,distance,opts);
   if(!(al instanceof Ok&&bl instanceof Ok))throw Error('Sampling error');
   const combine=(x,y)=>f.op==='unite'?(x!==0||y!==0):(x!==0&&y!==0);
   const l=combine(al[0][0],bl[0][0]),r=combine(al[0][1],bl[0][1]);
   const orientation=l===r?0:l?-1:1;
   classified.push({id:e.id,a:clean(al[0]),b:clean(bl[0]),orientation});
   if(orientation)selected.push({id:e.id,start_vertex:orientation>0?e.start_vertex:e.end_vertex,end_vertex:orientation>0?e.end_vertex:e.start_vertex});
  }
  const entry={tolerance,distance,classified,selected,imbalance:balance(selected)};
  row.sweeps.push(entry);console.log(id,tolerance,distance,entry.imbalance.length,selected.length);
 }
 const base=row.sweeps[0],reference=row.sweeps.find(x=>x.tolerance===1e-8&&x.distance===16e-8);
 row.changedEdges=base.classified.filter((e,i)=>JSON.stringify(e)!==JSON.stringify(reference.classified[i])).map(e=>e.id);
 row.dual=dualClassification(built,left,f.op);
 row.samples=[];
 for(const e of graph.edges)if(row.changedEdges.includes(e.id)){
  for(const t of [.25,.5,.75])for(const distance of [16e-6,16e-7,16e-8]){
   const p=s.segment_point(e.segment,t)[0],v=s.segment_derivative(e.segment,t)[0],length=Math.hypot(v.x,v.y);
   const samples=[new s.Point(p.x+v.y/length*distance,p.y-v.x/length*distance),new s.Point(p.x-v.y/length*distance,p.y+v.x/length*distance)];
   const opts=ct.default_containment_options();opts.tolerance=1e-9;
   row.samples.push({edge:e.id,t,distance,points:samples.map(clean),paper:samples.map(p=>paperPaths.map(path=>({inside:path.contains(new paper.Point(p.x,p.y)),distance:path.getNearestPoint(new paper.Point(p.x,p.y)).getDistance(new paper.Point(p.x,p.y))}))),rawWindings:samples.map(p=>[clean(q.path_winding_with(p,left,opts)),clean(q.path_winding_with(p,right,opts))])});
  }
 }
 rows.push(row);console.log('changed edges',id,row.changedEdges);
}
const area=await imp('svg_path/area.mjs');
function triangle(ps){return s.subpath_as_path(s.subpath_assert_close(s.subpath_assert(toList(ps.map((p,i)=>new s.Line(new s.Point(...p),new s.Point(...ps[(i+1)%ps.length])))))));}
const reductions=[];
for(const [name,ps,qs,expectedArea] of [
 ['nested',[[0,0],[1,1],[0,2]],[[0,0],[1.00004,1],[0,2]],1.00004],
 ['thin',[[0,0],[0,-.00004],[-1,-1]],[[0,-.00004],[0,0],[1,-1]],.00004],
]){
 const left=triangle(ps),right=triangle(qs);
 const built=c.csg_arrangement_build(toList([left,right]),c.default_options());
 if(!(built instanceof Ok))throw Error('Reduced arrangement failed');
 globalThis.csgSideDistance=undefined;
 const original=c.union_path(left,right,new s.Nonzero());
 globalThis.csgSideDistance=1.6e-6;
 const smaller=c.union_path(left,right,new s.Nonzero());
 globalThis.csgSideDistance=undefined;
 const dual=dualClassification(built,left,'unite');
 const parsed=(await imp('svg_path/parse.mjs')).path(dual.outputPathData);
 const dualArea=parsed instanceof Ok?Math.abs(area.signed_path(parsed[0])):null;
 reductions.push({name,left:ps,right:qs,expectedArea,valid:clean(a.validate_closed_boundaries(built[0].graph,1e-6,1e-5)),original:clean(original),originalArea:original instanceof Ok?Math.abs(area.signed_path(original[0])):null,smaller:clean(smaller),smallerArea:smaller instanceof Ok?Math.abs(area.signed_path(smaller[0])):null,dual,dualArea});
 if(Math.abs(dualArea-expectedArea)>1e-12)throw Error('Incorrect reduced dual area');
}
fs.writeFileSync(path.join(repo,'scripts/paperjs/boundary-classification-investigation.json'),JSON.stringify({scratch,rows,reductions},null,2)+'\n');
console.log('Scratch',scratch);

if(process.argv.includes('--screen')){
 let probe=fs.readFileSync(path.join(repo,'scripts/paperjs/probe-booleans.mjs'),'utf8');
 probe=probe.replace("new URL('./booleans.json',import.meta.url)",JSON.stringify(path.join(repo,'scripts/paperjs/booleans.json')));
 probe=probe.replaceAll('../../test_portable/build/dev/javascript/svg_path/',pathToFileURL(path.join(scratch,'svg_path/')).href);
 probe=probe.replace('const selected=process.argv[3]===undefined?fixtures:', 'const selected=process.argv[3]===undefined?fixtures.filter(f=>[79,113].includes(f.id)):');
 probe=probe.replace('const f=workerData.fixture;', 'const f=workerData.fixture;globalThis.csgSideDistance=1.6e-6;');
 fs.writeFileSync(path.join(scratch,'probe.mjs'),probe);
 const result=spawnSync(process.execPath,[path.join(scratch,'probe.mjs'),'/tmp/svg-path-paper-audit/node_modules/paper'],{stdio:'inherit',env:{...process.env,PAPER_AUDIT_REPORT:pathToFileURL(path.join(repo,'scripts/paperjs/boundary-classification-experiment-screen.json')).href,PAPER_AUDIT_TIMEOUT_MS:'30000'}});
 if(result.status!==0)throw Error('Screen failed');
 const anchor="const r=fn(path(f.left),path(f.right),f.left.fillRule==='evenodd'?new s.EvenOdd():new s.Nonzero());";
 if(!probe.includes(anchor))throw Error('Result anchor changed');
 const reportFile=JSON.stringify(path.join(repo,'scripts/paperjs/boundary-classification-investigation.json'));
 const parseUrl=JSON.stringify(pathToFileURL(path.join(scratch,'svg_path/svg_path/parse.mjs')).href);
 const dualProbe=probe.replace(anchor,`const saved=JSON.parse(fs.readFileSync(${reportFile})).rows.find(x=>x.id===f.id);const r=(await import(${parseUrl})).path(saved.dual.outputPathData);`);
 fs.writeFileSync(path.join(scratch,'dual-probe.mjs'),dualProbe);
 const dualResult=spawnSync(process.execPath,[path.join(scratch,'dual-probe.mjs'),'/tmp/svg-path-paper-audit/node_modules/paper'],{stdio:'inherit',env:{...process.env,PAPER_AUDIT_REPORT:pathToFileURL(path.join(repo,'scripts/paperjs/boundary-dual-experiment-screen.json')).href,PAPER_AUDIT_TIMEOUT_MS:'30000'}});
 if(dualResult.status!==0)throw Error('Dual screen failed');
}
