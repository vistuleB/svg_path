from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-closed-pline1-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/offset.mjs';s=p.read_text()
for name in ['contamination_seed_faces','propagate_contaminated_faces','offside_trimmed_single_offset_subpath','offside_survivor_chains']:
 s=s.replace('function '+name+'(','function original_'+name+'(',1)
 s+='\nfunction '+name+'''(...args) {
 const result=original_'''+name+'''(...args);
 if ("'''+name+'''" === "offside_survivor_chains") globalThis.auditChains={args,result};
 if ("'''+name+'''" === "offside_trimmed_single_offset_subpath") globalThis.auditOffside={args,result};
 if ("'''+name+'''" === "contamination_seed_faces" && [...args[3]].length === 0) globalThis.auditSeeds=result;
 if ("'''+name+'''" === "propagate_contaminated_faces") globalThis.auditFlood=result;
 return result;
}
'''
p.write_text(s)
probe=(root/'scripts/cavalier/probe-offset-detail.mjs').read_text()
probe+='''
const plain=x=>x===null||typeof x!=='object'?x:(Symbol.iterator in x)?[...x].map(plain):{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v)]))};
console.error(JSON.stringify(plain({chains:globalThis.auditChains,offside:globalThis.auditOffside,seeds:globalThis.auditSeeds,flood:globalThis.auditFlood}),null,2));
'''
# Keep fixture-relative URL resolution in the original script directory.
(root/'scripts/cavalier/probe-closed-pline1-trace.mjs').write_text(probe)
