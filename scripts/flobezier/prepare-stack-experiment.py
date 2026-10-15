"""Copy compiled artifacts to /tmp; instrument and trial a JS-only loop rewrite.
No repository source or normal compiled artifacts are modified.
"""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
base=root/'test_portable/build/dev/javascript'
out=Path('/tmp/flobezier-stack-experiment')
shutil.copytree(base,out,dirs_exist_ok=True)
p=out/'svg_path/svg_path/intersections.mjs'
s=p.read_text()
needle='function inspect_projection_window(\n'
start=s.index(needle);body=s.index(') {',start)+3
s=s[:body]+'''\n  if(globalThis.projectionAudit){
    const a=globalThis.projectionAudit;a.inspections++;
    a.byDepth[remaining_depth]=(a.byDepth[remaining_depth]??0)+1;
  }
'''+s[body:]
# Observe the window count without affecting its construction.
needle='function number_terminal_windows('
start=s.index(needle);body=s.index(') {',start)+3
s=s[:body]+'''\n  if(globalThis.projectionAudit&&next_id===0)globalThis.projectionAudit.terminalCount=[...windows].length;
'''+s[body:]
p.write_text(s)
(out/'instrumented-original.mjs.txt').write_text(s)
start=s.index('      return $result.try$(\n        inspect_projection_window(',s.index('function collect_projection_terminal_windows_generation('))
end=s.index('\n    }\n  }\n}',start)
replacement='''      const inspected=inspect_projection_window(left,right,remaining_depth,best,windows,next_generation);
      if(!inspected.isOk()) return inspected;
      loop$this_generation=rest;
      loop$windows=inspected[0][0];
      loop$best=inspected[0][1];
      loop$next_generation=inspected[0][2];'''
(out/'iterative-trial.mjs.txt').write_text(s[:start]+replacement+s[end:])
print(out.as_uri()+'/')
