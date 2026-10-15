// Replace only specified cyclic orders in freshly built diagnostic graph copies.
import fs from 'node:fs';
const base=process.env.PROBE_RUNTIME;if(!base)throw Error('PROBE_RUNTIME required');
const g=await import(base+'svg_path/svg_path.mjs');
const arr=await import(base+'svg_path/svg_path/arrangement.mjs');
const csg=await import(base+'svg_path/svg_path/csg.mjs');
const area=await import(base+'svg_path/svg_path/area.mjs');
const {toList}=await import(base+'prelude.mjs');
const calls=fs.readFileSync(new URL('polygons-calls.jsonl',import.meta.url),'utf8').trim().split('\n').map(JSON.parse);
const analyses=JSON.parse(fs.readFileSync(new URL('remaining-topology-analysis.json',import.meta.url)));
const unwrap=r=>{if(!r.isOk())throw r[0];return r[0];};
const simple=r=>r.isOk()?{ok:true}:{error:r[0]};
const rows=[];
for(const analysis of analyses){
 const call=calls[analysis.id-1],n=call.input.edges.length;
 const segs=[...call.input.edges,...call.arguments[0].edges].map(e=>new g.Line(new g.Point(e.start.x,e.start.y),new g.Point(e.end.x,e.end.y)));
 const built=unwrap(arr.build_with(toList(segs),1e-6,1e-5,0));
 const changes=analysis.mismatches.filter(x=>x.mode==='segment');
 const samples=changes.map(change=>{
  const vertex=[...built.graph.vertices].find(v=>v.id===change.vertex);
  const darts=change.stored.map(([e,r])=>new arr.OrientedArrangementEdge(e,r));
  const lengths=darts.map(d=>{const e=[...built.graph.edges].find(e=>e.id===d.edge_id),p=d.reversed?e.segment.start:e.segment.end;return Math.hypot(p.x-vertex.point.x,p.y-vertex.point.y);});
  return {vertex:change.vertex,radii:[0,1,2].map(k=>{
   const radius=.8*Math.min(...lengths)*.8**k;
   const r=arr.diagnostic_samples(toList(darts),built.graph.edges,vertex.point,vertex.id,radius,1e-6);
   return {radius,result:r.isOk()?[...r[0]]:r[0]};
  })};
 });
 const reducedFans=changes.map(change=>{
  const ids=change.stored.map(d=>d[0]).filter(id=>!(analysis.id===3380&&id===39));
  const selected=[...built.graph.edges].filter(e=>ids.includes(e.id));
  const vertexIds=new Set(selected.flatMap(e=>[e.start_vertex,e.end_vertex]));
  const selectedVertices=[...built.graph.vertices].filter(v=>vertexIds.has(v.id));
  const center=selectedVertices.find(v=>v.id===change.vertex).point;
  return {vertex:change.vertex,edges:ids,variants:[false,true].map(centered=>{
   const move=p=>centered?new g.Point(p.x-center.x,p.y-center.y):p;
   const vertices=toList(selectedVertices.map(v=>new arr.ArrangementVertex(v.id,move(v.point),toList([...v.endpoint_samples].map(move)))));
   const edges=toList(selected.map(e=>{const segment=new g.Line(move(e.segment.start),move(e.segment.end));return new arr.ArrangementEdge(e.id,segment,unwrap(g.segment_bounding_box(segment)),e.start_vertex,e.end_vertex,e.forward_multiplicity,e.reverse_multiplicity);}));
   const fan=new arr.ArrangementGraph(vertices,edges,toList([]));
   const result=arr.vertex_cyclic_order_with(fan,change.vertex,1e-6,3);
   return {centered,groups:result.isOk()?[...result[0]].map(group=>[...group]):result[0]};
  })};
 });
 const centeredOrders=toList([...built.graph.vertices].map(vertex=>{
  const move=p=>new g.Point(p.x-vertex.point.x,p.y-vertex.point.y);
  const incident=[...built.graph.edges].filter(e=>e.start_vertex===vertex.id||e.end_vertex===vertex.id);
  const ids=new Set(incident.flatMap(e=>[e.start_vertex,e.end_vertex]));
  const vertices=toList([...built.graph.vertices].filter(v=>ids.has(v.id)).map(v=>new arr.ArrangementVertex(v.id,move(v.point),toList([...v.endpoint_samples].map(move)))));
  const edges=toList(incident.map(e=>{const segment=new g.Line(move(e.segment.start),move(e.segment.end));return new arr.ArrangementEdge(e.id,segment,unwrap(g.segment_bounding_box(segment)),e.start_vertex,e.end_vertex,e.forward_multiplicity,e.reverse_multiplicity);}));
  return [vertex.id,unwrap(arr.vertex_cyclic_order_with(new arr.ArrangementGraph(vertices,edges,toList([])),vertex.id,1e-6,3))];
 }));
 const experiments=[];
 for(const changed of [[],...changes.map(c=>[c]),...(changes.length>1?[changes]:[]),'centered']){
  const replacements=new Map((changed==='centered'?[]:changed).map(c=>[c.vertex,c]));
  // Retain the original group sizes; alter only the flattened incident order.
  const orders=changed==='centered'?centeredOrders:toList([...built.graph.cyclic_orders].map(([id,groups])=>{
   if(!replacements.has(id))return [id,groups];
   const seq=replacements.get(id).alternative;let offset=0;
   return [id,toList([...groups].map(group=>{const count=[...group].length;const out=seq.slice(offset,offset+count).map(([e,r])=>new arr.OrientedArrangementEdge(e,r));offset+=count;return toList(out);} ))];
  }));
  const graph=new arr.ArrangementGraph(built.graph.vertices,built.graph.edges,orders);
  const copy=new arr.ArrangementSegmentBuild(graph,built.segments,built.segment_images,built.edge_images);
  const dual=arr.dual(graph);
  const winds=dual.isOk()?[true,false].map(left=>{
   const weights=toList([...built.edge_images].map(image=>new arr.EdgeWindingChange(image.edge_id,[...image.sources].reduce((n,s)=>n+(((s.segment_index<call.input.edges.length)===left)?(s.reversed?-1:1):0),0))));
   return simple(arr.face_windings(dual[0],weights));
  }):null;
  const operations=[['union',new csg.UnionOperation()],['difference',new csg.DifferenceOperation()],['intersection',new csg.IntersectionOperation()]].map(([name,op])=>{
   const r=csg.diagnostic_boolean(copy,n,new g.EvenOdd(),op);
   return {name,...simple(r),signedArea:r.isOk()?area.signed_path(r[0]):null,segments:r.isOk()?[...r[0].subpaths].reduce((n,s)=>n+[...s.segments].length,0):null};
  });
  experiments.push({changedVertices:changed==='centered'?'all vertices resampled in local coordinates':changed.map(c=>c.vertex),dual:simple(dual),faces:dual.isOk()?[...dual[0].faces].length:null,winds,operations});
 }
 rows.push({id:analysis.id,samples,reducedFans,experiments});
 console.log(analysis.id,JSON.stringify(experiments));

}
fs.writeFileSync(new URL('remaining-topology-replay.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');
