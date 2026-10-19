"""Experiment only: prefer the unique existing-center match during attachment."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-owner-consistency')
shutil.copytree(root/'scripts/cavalier/probe/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
s=s.replace('function attach_vertex(vertices, endpoint, tolerance) {','function original_attach_vertex(vertices, endpoint, tolerance) {',1)
s+='''
function attach_vertex(vertices,endpoint,tolerance) {
 const match=unique_vertex_for_endpoint(vertices,endpoint,tolerance);
 if(match.isOk() && match[0] instanceof Some) {
  const id=match[0][0], v=[...vertices].find(v=>v.id===id);
  const chosen=original_attach_vertex(toList([v]),endpoint,tolerance);
  if(chosen[1]===id) {
   const replacement=[...chosen[0]].find(v=>v.id===id);
   const normal=original_attach_vertex(vertices,endpoint,tolerance);
   if(normal[1]!==id)(globalThis.ownerChanges??=[]).push({endpoint,old:normal[1],preferred:id});
   return [toList([...vertices].map(v=>v.id===id?replacement:v)),id];
  }
 }
 return original_attach_vertex(vertices,endpoint,tolerance);
}
'''
p.write_text(s)
