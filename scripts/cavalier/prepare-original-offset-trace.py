from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2];dest=Path('/tmp/cavalier-original-offset-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',dest,dirs_exist_ok=True)
p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text()
for name in ['retain_offset_image_edges','delete_winding_mismatched_edges','forced_parity_reduce_trim_graph','source_order_survivor_subpaths']:
 needle='function '+name+'(';assert s.count(needle)==1;s=s.replace(needle,'function original_'+name+'(',1)
 s+='''\nfunction NAME(...args) {
 const r=original_NAME(...args); const value=r && typeof r.isOk==='function' ? (r.isOk()?r[0]:null) : r;
 const graph=args.find(x=>x && x.edges && x.vertices);
 (globalThis.originalAuditStages??=[]).push({stage:'NAME',before:graph?[...graph.edges].length:null,after:value?.edges?[...value.edges].length:null,outputPaths:value&&Symbol.iterator in Object(value)?[...value].length:null,error:value===null});return r;
}\n'''.replace('NAME',name)
p.write_text(s)
probe=(root/'scripts/cavalier/probe-offset-detail.mjs').read_text()
probe+="\nconsole.error(JSON.stringify(globalThis.originalAuditStages));\n"
(root/'scripts/cavalier/probe-original-offset-trace.mjs').write_text(probe)
