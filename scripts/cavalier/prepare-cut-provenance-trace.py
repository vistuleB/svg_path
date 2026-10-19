from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('prepare-vertex-provenance-trace.py')))
p=Path('/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/arrangement.mjs');s=p.read_text()
for name in ['split_atomic_piece','vertex_projects_to_piece_interior','pair_cuts_with_common_endpoint_sliver']:
 s=s.replace('function '+name+'(', 'function cut_original_'+name+'(',1)
s+='''
function cut_record(kind, data) { console.error('CUTTRACE',JSON.stringify({kind,...data})); }
function split_atomic_piece(piece,cuts,tolerance,minimum_length) {
 cut_record('incoming-split',{piece,cuts:[...cuts],tolerance,minimum_length});
 return cut_original_split_atomic_piece(piece,cuts,tolerance,minimum_length);
}
function vertex_projects_to_piece_interior(vertex,segment,tolerance) {
 const r=cut_original_vertex_projects_to_piece_interior(vertex,segment,tolerance);
 if(r.isOk() && r[0] instanceof Some) cut_record('projection-cut',{vertex,segment,t:r[0][0],tolerance});
 return r;
}
function pair_cuts_with_common_endpoint_sliver(piece,edge,incoming_start,incoming_end,tolerance,sliver) {
 const r=cut_original_pair_cuts_with_common_endpoint_sliver(piece,edge,incoming_start,incoming_end,tolerance,sliver);
 if(r.isOk() && [...r[0]].length) cut_record('pair-cuts',{piece,edge,cuts:[...r[0]],tolerance,sliver});
 return r;
}
'''
s=s.replace("audit_vertex_record({kind:'split-edge',", "cut_record('edge-split-caller',{caller:new globalThis.Error().stack.split('\\n').slice(2,6)}); audit_vertex_record({kind:'split-edge',")
p.write_text(s)
