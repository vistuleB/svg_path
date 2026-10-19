"""Add observational vertex/edge provenance to the existing copied JS trace."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('prepare-near-tangent-trace.py')))
p=Path('/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/arrangement.mjs')
s=p.read_text()
for name in ['attach_vertex','split_progressive_graph_edge','validate_piece_endpoint_vertices']:
 s=s.replace('function '+name+'(', 'function audit_original_'+name+'(',1)
s+='''
function audit_vertex_record(value) {
 (globalThis.auditVertexTrace ??= []).push(value);
}
function attach_vertex(vertices, endpoint, tolerance) {
 const result=audit_original_attach_vertex(vertices,endpoint,tolerance);
 const old=[...vertices].find(v=>v.id===result[1]);
 const vertex=[...result[0]].find(v=>v.id===result[1]);
 audit_vertex_record({kind:'attach',endpoint,tolerance,id:result[1],created:!old,
  old:old?{point:old.point,count:[...old.endpoint_samples].length}:null,
  current:{point:vertex.point,count:[...vertex.endpoint_samples].length},
  caller:new globalThis.Error().stack.split('\\n').slice(2,5)});
 return result;
}
function split_progressive_graph_edge(graph,images,edge_id,cuts,tolerance,minimum_length) {
 audit_vertex_record({kind:'split-edge',edge:[...graph.edges].find(e=>e.id===edge_id),cuts:[...cuts],tolerance,minimum_length});
 return audit_original_split_progressive_graph_edge(graph,images,edge_id,cuts,tolerance,minimum_length);
}
function validate_piece_endpoint_vertices(piece, graph, vertex_tolerance) {
 const result=audit_original_validate_piece_endpoint_vertices(piece,graph,vertex_tolerance);
 if(!result.isOk()) audit_vertex_record({kind:'failed-piece',piece,vertices:[...graph.vertices].map(v=>({...v,endpoint_samples:[...v.endpoint_samples]})),edges:[...graph.edges],vertex_tolerance});
 return result;
}
'''
s=s.replace('export function build_with(segments, vertex_tolerance, minimum_length, endpoint_sliver_tolerance) {', 'export function build_with(segments, vertex_tolerance, minimum_length, endpoint_sliver_tolerance) { audit_vertex_record({kind:"source",segments:[...segments],vertex_tolerance,minimum_length,endpoint_sliver_tolerance});')
# Compiler may lay the signature over multiple lines.
a=s.index('export function build_with('); b=s.index(') {',a)+3
if 'audit_vertex_record' not in s[b:b+80]:
 s=s[:b]+'\n audit_vertex_record({kind:"source",segments:[...segments],vertex_tolerance,minimum_length,endpoint_sliver_tolerance});'+s[b:]
p.write_text(s)

# Optional experiment only in the copied JS build; production source untouched.
import os
if os.environ.get('AUDIT_PRESERVE_VERTEX_MEMBERSHIP') == '1':
 s=p.read_text().replace('function audit_original_attach_vertex(vertices, endpoint, tolerance) {', '''function audit_original_attach_vertex(vertices, endpoint, tolerance) {
 const owner=[...vertices].find(v=>[...v.endpoint_samples].some(p=>p.x===endpoint.x && p.y===endpoint.y));
 if(owner) return [replace_vertex(vertices,new ArrangementVertex(owner.id,owner.point,listPrepend(endpoint,owner.endpoint_samples))),owner.id];
''',1)
 p.write_text(s)

if os.environ.get('AUDIT_TRACE_PROGRESS') == '1':
 s=p.read_text().replace('(globalThis.auditVertexTrace ??= []).push(value);', '''
 const events=(globalThis.auditVertexTrace ??= []);
 events.push(value);
 if(events.length % 25 === 0) console.error('vertex-event-progress',events.length,JSON.stringify(value));
''',1)
 p.write_text(s)
