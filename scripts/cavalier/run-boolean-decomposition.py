"""Replay all 56 previously witness-free Not/Xor flags, with per-case limits."""
import json,os,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
cases={c['id']:c for c in json.loads((root/'captured-cases.json').read_text())}
old=[json.loads(l) for l in (root/'boolean-remaining.jsonl').read_text().splitlines()]
ids=[r['id'] for r in old if r.get('mismatches')==[] and cases[r['id']]['operation'] in ['Not','Xor']]
assert len(ids)==56
node=os.environ.get('NODE','node')
with (root/'boolean-decomposition-current.jsonl').open('w') as dest:
 for id in ids:
  start=time.monotonic()
  try:
   p=subprocess.run([node,str(root/'probe-boolean-scanlines.mjs')],env={**os.environ,'CASE_ID':id},capture_output=True,text=True,timeout=60)
   r=json.loads(p.stdout) if p.returncode==0 else {'id':id,'probe_error':p.stderr}
  except subprocess.TimeoutExpired:r={'id':id,'timeout_seconds':60}
  r['elapsed_seconds']=time.monotonic()-start
  dest.write(json.dumps(r,separators=(',',':'))+'\n');dest.flush()
  print(id,'probe error' if 'probe_error' in r else 'timeout' if 'timeout_seconds' in r else f"{r['checked']} levels; clearance {r['maxWitnessClearance']:.3g}",flush=True)
