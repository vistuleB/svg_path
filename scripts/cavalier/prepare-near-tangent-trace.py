"""Observe errors in a copied generated JS build, preserving return values."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-near-tangent-offset-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
for name in ['offset','arrangement']:
 p=target/f'svg_path/svg_path/{name}.mjs';s=p.read_text()
 s=s.replace('export function public_error(error) {','export function public_error(error) {\n  (globalThis.auditErrors ??= []).push({module: "'+name+'",error});',1);p.write_text(s)
p=target/'svg_path/svg_path.mjs';s=p.read_text().replace('export function arc_center_data(segment) {','function audit_original_arc_center_data(segment) {',1)
s+='''
export function arc_center_data(segment) {
 const result=audit_original_arc_center_data(segment);
 if(!result.isOk() && segment instanceof Arc) {
  globalThis.auditArcs ??= [];
  if(globalThis.auditArcs.length<20)globalThis.auditArcs.push({segment,error:result[0],stack:new globalThis.Error().stack});
 }
 return result;
}
''';p.write_text(s)

p=target/'svg_path/svg_path.mjs';s=p.read_text().replace('export function segment_between_inside(segment, from, to) {','function audit_original_segment_between_inside(segment, from, to) {',1)
s+="""
export function segment_between_inside(segment, from, to) {
 const result=audit_original_segment_between_inside(segment,from,to);
 if(!result.isOk()) (globalThis.auditBetween ??= []).push({segment,from,to,error:result[0]});
 return result;
}
"""
p.write_text(s)

p=target/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
s=s.replace('return new Error(InternalError$InternalNormalizationError$const);', 'console.error("normalization failure", new globalThis.Error().stack); return new Error(InternalError$InternalNormalizationError$const);')
s=s.replace('(_) => { return InternalError$InternalNormalizationError$const; }', '(error) => { console.error("normalization mapping", error, new globalThis.Error().stack); return InternalError$InternalNormalizationError$const; }')
p.write_text(s)

p=target/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
s=s.replace('return unique_vertex_for_endpoint_loop(\n    vertices,', 'const result = unique_vertex_for_endpoint_loop(\n    vertices,', 1)
a=s.index('function unique_vertex_for_endpoint(vertices, endpoint, vertex_tolerance)')
b=s.index('\n}',a)
s=s[:b]+"\n  if (!result.isOk()) console.error('ambiguous endpoint', JSON.stringify({endpoint,vertex_tolerance,matches:[...vertices].filter(v=>$point.distance(endpoint,v.point)<=vertex_tolerance).map(v=>({id:v.id,point:v.point,distance:$point.distance(endpoint,v.point)}))}));\n  return result;"+s[b:]
p.write_text(s)
