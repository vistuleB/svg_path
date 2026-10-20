"""Instrument a copied JavaScript build; wrappers preserve all return values."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[2]
target = Path('/tmp/cavalier-open-pline4-trace')
shutil.copytree(root / 'test_portable/build/dev/javascript', target, dirs_exist_ok=True)
p = target / 'svg_path/svg_path/offset.mjs'
s = p.read_text()
for name in ['retain_offset_image_edges', 'delete_winding_mismatched_edges', 'forced_parity_reduce_trim_graph', 'source_order_survivor_subpaths', 'arrangement_edge_winding_matches_opinion', 'single_offset_segment_arrangement']:
    needle = 'function ' + name + '('
    assert s.count(needle) == 1, name
    s = s.replace(needle, 'function original_' + name + '(', 1)
    s += '\nfunction ' + name + '''(...args) {
 const result = original_''' + name + '''(...args);
 const entry = {stage: "''' + name + '''", result};
 if (entry.stage === 'single_offset_segment_arrangement') { globalThis.auditWindingPath = args[3]; return result; }
 if (entry.stage === 'arrangement_edge_winding_matches_opinion') {
   entry.edge = args[1];
   entry.expected = arrangement_edge_winding_opinion(args[0], args[1].id);
   entry.measured = $dict.get(args[2], args[1].id);
 } else if (entry.stage === 'delete_winding_mismatched_edges') {
   entry.build = args[0];
 } else if (entry.stage === 'forced_parity_reduce_trim_graph') {
   entry.protected = args[1];
 }
 (globalThis.auditStages ??= []).push(entry);
 return result;
}
'''
p.write_text(s)
probe = (root / 'scripts/cavalier/probe-offset-detail.mjs').read_text()
probe += '''
const plain=x=>x===null||typeof x!=='object'?x:(Symbol.iterator in x)?[...x].map(plain):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v)]))};
console.error(JSON.stringify(plain(globalThis.auditStages),null,2));
const containment = await import(`${build}/svg_path/svg_path/containment.mjs`);
const samples = globalThis.auditStages.filter(r=>r.edge).map(r=>{
 const p=unwrap(g.segment_point(r.edge.segment,.5)),d=unwrap(g.segment_derivative(r.edge.segment,.5)),n=Math.hypot(d.x,d.y);
 return {edge:r.edge.id,measured:r.measured[0],samples:[1e-3,1e-4,1e-5].map(e=>({epsilon:e,pair:[1,-1].map(sign=>{
 const q=new g.Point(p.x-sign*e*d.y/n,p.y+sign*e*d.x/n);
 return plain(containment.path_winding(q,globalThis.auditWindingPath));
 })}))};
});
fs.writeFileSync(new URL('./offset-post-reversal-CC01287-winding-samples.json',import.meta.url),JSON.stringify(samples,null,2)+'\\n');
'''
(root / 'scripts/cavalier/probe-open-pline4-trace.mjs').write_text(probe)
