"""Diagnostic copied-JS experiments; production sources remain untouched."""
import json, os, shutil, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
build=root/'test_portable/build/dev/javascript'
node='/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin/node'
out=[]
for mode in ['baseline','skip-short','skip-both','segmentwise']:
    dest=Path('/tmp/cavalier-short-run-'+mode)
    shutil.copytree(build,dest,dirs_exist_ok=True)
    p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text()
    if mode!='baseline':
        old='normalize_short_source_runs(subpath, 0.001)'
        assert s.count(old)==1
        s=s.replace(old,'new Ok(subpath)')
    if mode in ['skip-both','segmentwise']:
        old='$degeneracy.normalize_degenerate_segments(\n                subpath,\n                options.fitting.tolerance,\n              )'
        assert s.count(old)==1
        replacement = 'new Ok(subpath)'
        if mode=='segmentwise':
            replacement = """(() => {
              const pieces=[];
              for (const segment of $svg_path.subpath_segments(subpath)) {
                const single=$svg_path.subpath(toList([segment]));
                if (!single.isOk()) return single;
                const normalized=$degeneracy.normalize_degenerate_segments(single[0], options.fitting.tolerance);
                if (!normalized.isOk()) return normalized;
                pieces.push(...$svg_path.subpath_segments(normalized[0]));
              }
              const result=$svg_path.subpath(toList(pieces));
              if (!result.isOk() || !$svg_path.subpath_is_closed(subpath)) return result;
              return $svg_path.subpath_close(result[0]);
            })()"""
        s=s.replace(old,replacement)
    s=s.replace("export function public_error(error) {", "export function public_error(error) { console.error(JSON.stringify({internalError:error.constructor.name,...error}));")
    p.write_text(s)
    for tolerance in ['0.01','0.00001']:
        env={**os.environ,'AUDIT_JS_BUILD':str(dest),'AUDIT_CASE_ID':'CC01301','AUDIT_TOLERANCE':tolerance}
        try:
            r=subprocess.run([node,str(root/'scripts/cavalier/probe-short-transition.mjs')],env=env,capture_output=True,text=True,timeout=60)
            out.append({'mode':mode,'tolerance':float(tolerance),'exit':r.returncode,'stderr':r.stderr,'result':json.loads(r.stdout) if r.returncode==0 else r.stderr})
        except subprocess.TimeoutExpired:
            out.append({'mode':mode,'tolerance':float(tolerance),'timeout_seconds':60})
        print(mode,tolerance, 'complete',flush=True)
(root/'scripts/cavalier/short-run-normalization-experiment.json').write_text(json.dumps(out,indent=2)+'\n')
