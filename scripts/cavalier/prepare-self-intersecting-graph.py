from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2];dest=Path('/tmp/self-intersecting-graph')
shutil.copytree(root/'test_portable/build/dev/javascript',dest,dirs_exist_ok=True)
p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text()
for name in ['delete_winding_mismatched_edges','forced_parity_reduce_trim_graph']:
 needle='function '+name+'(';assert s.count(needle)==1;s=s.replace(needle,'function original_'+name+'(',1)
 s+='''\nfunction NAME(...args) {
 const result=original_NAME(...args);
 (globalThis.graphStages??=[]).push({stage:'NAME',args,result}); return result;
}\n'''.replace('NAME',name)
p.write_text(s)
probe=(root/'scripts/cavalier/probe-offset-detail.mjs').read_text()
probe+='''\nconst plain=x=>x===null||typeof x!=='object'?x:(Symbol.iterator in x)?[...x].map(plain):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v)]))};
console.error(JSON.stringify(plain(globalThis.graphStages),null,2));\n'''
(dest/'probe.mjs').write_text(probe)
