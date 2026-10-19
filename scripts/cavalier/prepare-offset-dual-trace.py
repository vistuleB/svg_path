from pathlib import Path
import runpy,re
root=Path(__file__).resolve().parents[2]
runpy.run_path(str(Path(__file__).with_name('prepare-near-tangent-trace.py')))
p=Path('/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/arrangement.mjs');s=p.read_text()
for name in ['dual_sweep_intersections','dual_find_exteriors','dual_find_placements','dual']:
 pattern=r'(export )?function '+name+r'\(';m=re.search(pattern,s);assert m
 s=re.sub(pattern,'function audit_original_'+name+'(',s,count=1)
 s+='\n'+('export ' if m.group(1) else '')+f'''function {name}(...args) {{
 const r=audit_original_{name}(...args);
 const counts=(globalThis.auditDualCounts??={{}}), key='{name}:'+(r.isOk()?'Ok':(r[0]?.constructor?.name??'Nil'));
 counts[key]=(counts[key]??0)+1;
 if(!r.isOk() && '{name}'==='dual')globalThis.auditFailedGraph={{vertices:[...args[0].vertices],edges:[...args[0].edges],cyclic_orders:[...args[0].cyclic_orders]}};
 if(!r.isOk() && '{name}'==='dual_sweep_intersections'){{
  const samples=(globalThis.auditRejectedSweeps??=[]);
  if(samples.length<8)samples.push({{line:args[2],tolerance:args[3],error:{{type:(r[0]?.constructor?.name??'Nil'),...r[0]}}}});
 }}
 return r;
}}
'''
p.write_text(s)
s=(root/'scripts/cavalier/probe-offset-detail.mjs').read_text().replace('../../test_portable/build/dev/javascript','/tmp/cavalier-near-tangent-offset-trace')
s+='\nconsole.error(JSON.stringify({counts:globalThis.auditDualCounts,rejected:globalThis.auditRejectedSweeps,graph:globalThis.auditFailedGraph,errors:(globalThis.auditErrors??[]).map(e=>({module:e.module,type:e.error.constructor.name,...e.error}))},null,2));\n'
(root/'scripts/cavalier/probe-offset-dual-trace.mjs').write_text(s)
