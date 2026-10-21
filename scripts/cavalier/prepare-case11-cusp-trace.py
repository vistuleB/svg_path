"""Instrument a disposable build without changing trim decisions."""
from pathlib import Path
import shutil, os
root=Path(__file__).resolve().parents[2];dest=Path('/tmp/case11-cusp-trace')
shutil.copytree(Path(os.environ.get('CUSP_TRACE_BUILD',root/'test_portable/build/dev/javascript')),dest,dirs_exist_ok=True)
p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text();name='finish_cusp_trim_with_parity';s=s.replace('function '+name+'(', 'function original_'+name+'(',1)
s=s.replace('function cusp_trim_parity_survivor_chains(', 'function original_cusp_trim_parity_survivor_chains(',1)
s+='''
function cusp_trim_parity_survivor_chains(current,graph,protectedVertices) {
 const entry={current:Array.from(current,s=>({segment:s.segment,edge_id:s.edge_id,start_vertex:s.start_vertex,end_vertex:s.end_vertex,deletion_candidate:s.deletion_candidate}))};
 (globalThis.cuspAttempts??=[]).push(entry);
 const result=original_cusp_trim_parity_survivor_chains(current,graph,protectedVertices);
 entry.result=result;
 return result;
}
function finish_cusp_trim_with_parity(split,rescued,build) {
 const result=original_finish_cusp_trim_with_parity(split,rescued,build);
 const slim=s=>({segment:s.segment,edge_id:s.edge_id,start_vertex:s.start_vertex,end_vertex:s.end_vertex,reversed:s.reversed,deletion_candidate:s.deletion_candidate,preimage_type:s.preimage.preimage.constructor.name});
 (globalThis.cuspTraces??=[]).push({before:Array.from(split.segments,slim),afterRescue:Array.from(rescued,slim),graph:build.graph,result,attempts:globalThis.cuspAttempts??[]});
 return result;
}
''';p.write_text(s)
s=(root/'scripts/cavalier/probe-offset-detail.mjs').read_text();s=s.replace("const trimming=new off.SingleOffsetTrimming(mode==='default'||mode==='offside-only',mode==='default'||mode==='no-offside'?new off.InBandTrimming():new off.NoTrimming());", "const trimming=new off.SingleOffsetTrimming(mode==='cusp-offside',new off.CuspTrimming());")
s+='''
const plain=x=>x===null||typeof x!=='object'?x:(Symbol.iterator in x)?[...x].map(plain):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v)]))};
console.error(JSON.stringify(plain(globalThis.cuspTraces??[]),null,2));
''';(dest/'probe.mjs').write_text(s)
